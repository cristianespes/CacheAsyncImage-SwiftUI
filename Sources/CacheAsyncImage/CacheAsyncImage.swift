//
//  CacheAsyncImage.swift
//
//  Created by Cristian Espes on 16/4/23.
//

import SwiftUI

public struct CacheAsyncImage<I: View, P: View, E: View>: View {
    
    let url: URL?
    @ViewBuilder let image: (Image) -> I
    @ViewBuilder let placeholder: () -> P
    @ViewBuilder let error: () -> E
    
    private let imageCache: ImageCache
    
    public init(url: URL?,
                enableLogs: Bool = false,
                @ViewBuilder image: @escaping (Image) -> I,
                @ViewBuilder placeholder: @escaping () -> P,
                @ViewBuilder error: @escaping () -> E) {
        self.url = url
        self.image = image
        self.placeholder = placeholder
        self.error = error
        
        imageCache = ImageCache(enabledLogs: enableLogs)
    }
    
    @State private var showPlaceholder: Bool = true
    @State private var value: Image?
    
    public var body: some View {
        VStack {
            if showPlaceholder {
                placeholder()
            } else {
                if let value {
                    image(value)
                } else {
                    error()
                }
            }
        }
        .task {
            guard value == nil else { return }
            value = await imageCache.getImage(url: url)
            showPlaceholder = false
        }
    }
}
