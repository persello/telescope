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
    
    var remoteImage: RemoteImage?
    private var isResizable: Bool = false
    private var placeholder: AnyView = AnyView(Image(systemName: "exclamationmark.triangle").font(.largeTitle))
    
    @State var loadedImage: UIImage?
    
    /// The content and behavior of the view.
    public var body: some View {
        GeometryReader { geometry in
            if let r = remoteImage {
                if let image = loadedImage {
                    
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
                        .onAppear {
                            try? remoteImage?.image(completion: { i in
                                if let image = i {
                                    if image.size.width > geometry.frame(in: .local).size.width ||
                                        image.size.height > geometry.frame(in: .local).size.height {
                                        
                                        // Resize image
                                        loadedImage = image.scaleWith(newSize: geometry.size)
                                        
                                        // Save resized
                                        if let resized = loadedImage {
                                            try? remoteImage?.editOriginal(newImage: resized)
                                        }
                                    } else {
                                        loadedImage = image
                                    }
                                }
                            })
                        }
                }
            } else {
                
                // No image
                placeholder
            }
        }
    }
    
    /// Makes the current image resizable.
    /// - Returns: A resizable `TImage`.
    public func resizable() -> TImage {
        var newImage = self
        newImage.isResizable = true
        return newImage
    }
    
    
    /// Adds an error placeholder view.
    /// - Parameter placeholder: The placeholder view.
    /// - Returns: A `TImage` with the specified placeholder.
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
            .frame(width: 120, height: 240, alignment: .center)
    }
}
