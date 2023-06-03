//
//  ImageCache.swift
//
//  Created by Cristian Espes on 16/4/23.
//

import SwiftUI

private var cache: [String: Image] = [:]

final class ImageCache {
    
    private let storageDirectory: URL
    private let enabledLogs: Bool
    
    init(enabledLogs: Bool) {
        if #available(iOS 16.0, *) {
            storageDirectory = URL.temporaryDirectory
        } else {
            storageDirectory = FileManager.default.temporaryDirectory
        }
        self.enabledLogs = enabledLogs
    }
    
    @MainActor
    func getImage(url: URL?) async -> Image? {
        guard let url else { return nil }
        
        if let localImage = fetchImageFromLocal(for: getID(for: url)) {
            return localImage
        } else {
            return await fetchImageFromNetwork(for: url)
        }
    }
    
}

private extension ImageCache {
 
    func fetchImageFromLocal(for id: String) -> Image? {
        if let image = cache[id] {
            return image
        }
        
        let imageUrl = storageDirectory.appendingPathComponent(id)
        
        if #available(iOS 16.0, *) {
            if FileManager.default.fileExists(atPath: imageUrl.path()),
               let uiImage = UIImage(contentsOfFile: imageUrl.path()) {
                let image = Image(uiImage: uiImage)
                cache[id] = image
                
                return image
            } else {
                return nil
            }
        } else {
            if FileManager.default.fileExists(atPath: imageUrl.path),
               let uiImage = UIImage(contentsOfFile: imageUrl.path) {
                let image = Image(uiImage: uiImage)
                cache[id] = image
                
                return image
            } else {
                return nil
            }
        }
    }
    
    func fetchImageFromNetwork(for url: URL?) async -> Image? {
        guard let url else { return nil }
        
        let request = URLRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let uiImage = UIImage(data: data) else { return nil }
            
            try Task.checkCancellation()
            
            let maxByte = 524_288 // 0.5MB
            let compressedUiImage = await uiImage.compress(toByte: maxByte)
            let image = Image(uiImage: compressedUiImage ?? uiImage)
            
            let id = getID(for: url)
            cache[id] = image
            saveImage(withID: id, data: compressedUiImage?.pngData() ?? data)
            
            return image
        } catch (let error) {
            #if DEBUG
            if enabledLogs {
                print(error.localizedDescription)
            }
            #endif
            return nil
        }
    }
    
    func saveImage(withID id: String, data: Data) {
        let imagePath = storageDirectory.appendingPathComponent(id)
        
        do {
            try data.write(to: imagePath, options: .atomic)
            #if DEBUG
            if enabledLogs {
                print("Saved image at path: \(imagePath)")
            }
            #endif
        } catch (let error) {
            #if DEBUG
            if enabledLogs {
                print(error.localizedDescription)
            }
            #endif
        }
    }
    
    private func getID(for url: URL) -> String {
        var id = url.relativePath
        
        if id.hasPrefix("/") {
            id.remove(at: id.startIndex)
        }
        
        return id.replacingOccurrences(of: "/", with: "_")
    }
    
}

extension UIImage {
    
    func compress(toByte maxByte: Int) async -> UIImage? {
        let compressTask = Task(priority: .userInitiated) { () -> UIImage? in
            guard let currentImageSize = jpegData(compressionQuality: 1.0)?.count else { return nil }
            
            var iterationImage: UIImage? = self
            var iterationImageSize = currentImageSize
            var iterationCompression: CGFloat = 1.0
            
            while iterationImageSize > maxByte && iterationCompression > 0.01 {
                let percentageDecrease = getPercentageToDecreaseTo(forDataCount: iterationImageSize)
                let canvasSize = CGSize(width: size.width * iterationCompression, height: size.height * iterationCompression)
                
                UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
                defer { UIGraphicsEndImageContext() }
                draw(in: CGRect(origin: .zero, size: canvasSize))
                iterationImage = UIGraphicsGetImageFromCurrentImageContext()
                
                guard let newImageSize = iterationImage?.jpegData(compressionQuality: 1.0)?.count else { return nil }
                iterationImageSize = newImageSize
                iterationCompression -= percentageDecrease
            }
            
            return iterationImage
        }
        return await compressTask.value
    }
    
    private func getPercentageToDecreaseTo(forDataCount dataCount: Int) -> CGFloat {
        switch dataCount {
            case 0..<3000000: return 0.05
            case 3000000..<10000000: return 0.1
            default: return 0.2
        }
    }
    
}
