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
    private var showProgressView: Bool = true
    
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
                            .scaledToFill()
                    } else {
                        Image(nsImage: image)
                    }
                    #else
                    if isResizable {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(uiImage: image)
                    }
                    #endif
                } else if r.hasLoadingError {
                    
                    // Loading error
                    placeholder
                } else {
                    // Load in progress
                    // VStack for centering
                    VStack(alignment: .center) {
                        if showProgressView {
                            ProgressView()
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                        }
                    }
                    .onAppear {
                        try? remoteImage?.image(completion: { i in
                            if let image = i {
                                
                                let scale: CGFloat
                                
                                #if os(macOS)
                                scale = NSScreen.main?.backingScaleFactor ?? 1
                                #else
                                scale = UIScreen.main.scale
                                #endif
                                
                                if image.size.width > geometry.size.width * scale ||
                                    image.size.height > geometry.size.height * scale {
                                    
                                    // Resize image
                                    
                                    // Calculate correct size
                                    let imageAspectRatio = image.size.width / image.size.height
                                    
                                    // Calculate reference side
                                    // We should scale the image by keeping at least the geometryreader's size
                                    // So we take the image's smaller side and scale the image based on it
                                    
                                    let scalingRatio: CGFloat!
                                    if (imageAspectRatio >= 1) {
                                        // We have image width > height
                                        scalingRatio = geometry.size.height / image.size.height
                                    } else {
                                        // height > width
                                        scalingRatio = geometry.size.width / image.size.width
                                    }
                                    
                                    // With this small change, we actually have large performance gains at a minimum memory cost
                                    if scalingRatio < 1.3 {
                                        loadedImage = image
                                        return
                                    }
                                    
                                    loadedImage = image.scaleWith(newSize: CGSize(width: image.size.width * scale * scalingRatio, height: image.size.height * scale * scalingRatio))
                                    
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
    
    /// Hides the progress view while loading.
    /// - Returns: A `TImage` without `ProgressView`
    /// - Note: This is useful for drawing groups, as animated views are not allowed.
    public func hideProgressView() -> TImage {
        var newImage = self
        newImage.showProgressView = false
        return newImage
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
        TImage(try? RemoteImage(stringURL: "https://picsum.photos/400/800"))
            .resizable()
            .placeholder({
                Text("Error!")
            })
            .frame(width: 200, height: 300, alignment: .center)
            .clipped()
    }
}
