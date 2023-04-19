//
//  ImageCache.swift
//
//  Created by Cristian Espes on 16/4/23.
//

import SwiftUI

private var cache: [String: Image] = [:]

@MainActor
final class ImageCache {
    
    private let storageDirectory: URL = URL.temporaryDirectory
    
    func getImage(url: URL?) async -> Image? {
        guard let url else { return nil }
        
        if let localImage = fetchImageFromLocal(for: url.lastPathComponent) {
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
        
        if FileManager.default.fileExists(atPath: imageUrl.path()),
           let uiImage = UIImage(contentsOfFile: imageUrl.path()) {
            let image = Image(uiImage: uiImage)
            cache[id] = image
            
            return image
        } else {
            return nil
        }
    }
    
    func fetchImageFromNetwork(for url: URL?) async -> Image? {
        guard let url else { return nil }
        
        let request = URLRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let uiImage = UIImage(data: data) else { return nil }
            
            let image = Image(uiImage: uiImage)
            
            let id = url.lastPathComponent
            cache[id] = image
            saveImage(withID: id, data: data)
            
            return image
        } catch (let error) {
            #if DEBUG
            print(error.localizedDescription)
            #endif
            return nil
        }
    }
    
    func saveImage(withID id: String, data: Data) {
        let imagePath = storageDirectory.appendingPathComponent(id)
        
        #if DEBUG
        print("Saved image at path: \(imagePath)")
        #endif
        
        do {
            try data.write(to: imagePath, options: .atomicWrite)
        } catch (let error) {
            #if DEBUG
            print(error.localizedDescription)
            #endif
        }
    }
    
}
