//
//  SwiftUIView.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

import SwiftUI
import os

/// A remote image in the form of a SwiftUI `View`.
@available(iOS 14.0, macOS 11, tvOS 14.0, *)
public struct TImage: View, Equatable {
    
    // Equatable protocol
    public static func == (lhs: TImage, rhs: TImage) -> Bool {
        return lhs.remoteImage == rhs.remoteImage
    }
    
    /// Creates a new instance of a Telescope `TImage`.
    /// - Parameter remoteImage: The remote image reference.
    public init(_ remoteImage: RemoteImage?) {
        self.remoteImage = remoteImage
    }
    
    var remoteImage: RemoteImage?
    private var isResizable: Bool = false
    private var placeholder: AnyView = AnyView(Image(systemName: "exclamationmark.triangle").font(.largeTitle))
    private var showProgressView: Bool = true
    private var fill: Bool = true
    
    private let logger = Logger(subsystem: "com.persello.telescope", category: "TImage")
    
    @State var loadedImage: UIImage?
    
    /// The content and behavior of the view.
    public var body: some View {
        GeometryReader { geometry in
            if let r = remoteImage {
                if let image = loadedImage {
                    
                    VStack(alignment: .center) {
                        // Real image
                        #if os(macOS)
                        if isResizable {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: fill ? .fill : .fit)
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                        } else {
                            Image(nsImage: image)
                        }
                        #else
                        if isResizable {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: fill ? .fill : .fit)
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                        } else {
                            Image(uiImage: image)
                        }
                        #endif
                    }
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
                        
                        // Save it, as it gets zero when scrolling and not in view
                        let recordedGeometrySize = geometry.size
                        
                        try? remoteImage?.image(withSize: recordedGeometrySize, completion: { image in
                            if let image = image {
                                loadedImage = image
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
    
    /// Makes the `TImage` fit into its parent. Default behaviour is fill.
    /// - Returns: A new fitted `TImage`.
    public func scaledToFit() -> TImage {
        var newImage = self
        newImage.fill = false
        return newImage
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
        TImage(try? RemoteImage(stringURL: "https://picsum.photos/1400/2800"))
            .resizable()
            .placeholder({
                Text("Error!")
            })
            .frame(width: 200, height: 600, alignment: .center)
            .clipped()
    }
}
