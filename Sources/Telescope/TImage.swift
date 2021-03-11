//
//  SwiftUIView.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

import SwiftUI

/// A remote image in the form of a SwiftUI `View`.
@available(iOS 14.0, macOS 11, tvOS 14.0, *)
public struct TImage: View {
    
    /// Creates a new instance of a Telescope `TImage`.
    /// - Parameter remoteImage: The remote image reference.
    public init(_ remoteImage: RemoteImage?) {
        self.remoteImage = remoteImage
    }
    
    private init(_ remoteImage: RemoteImage?, resizable: Bool) {
        self.init(remoteImage)
        self.isResizable = true
    }
    
    var remoteImage: RemoteImage?
    private var isResizable: Bool = false
    private var placeholder: AnyView = AnyView(Image(systemName: "exclamationmark.triangle").font(.largeTitle))
    
    /// The content and behavior of the view.
    public var body: some View {
        if let r = remoteImage {
            if let image = try? r.image() {
                
                // Real image
                
                #if os(macOS)
                if isResizable {
                    Image(nsImage: image)
                        .resizable()
                } else {
                    Image(nsImage: image)
                }
                #else
                if isResizable {
                    Image(uiImage: image)
                        .resizable()
                } else {
                    Image(uiImage: image)
                }
                #endif
            } else if r.hasLoadingError {
                
                // Loading error
                placeholder
            } else {
                
                // Load in progress
                ProgressView()
            }
        } else {
            
            // No image
            placeholder
        }
    }
    
    public func resizable() -> TImage {
        var newImage = self
        newImage.isResizable = true
        return newImage
    }
    
    public func placeholder<Placeholder: View>(@ViewBuilder _ placeholder: @escaping () -> Placeholder) -> TImage {
        var newImage = self
        newImage.placeholder = AnyView(placeholder())
        return newImage
    }
}

struct TImage_Previews: PreviewProvider {
    static var previews: some View {
        TImage(try? RemoteImage(stringURL: "https://picsum.photos/800/800"))
            .resizable()
            .placeholder({
                Text("Error!")
            })
            .scaledToFit()
            .frame(width: 800, height: 1200, alignment: .center)
    }
}
