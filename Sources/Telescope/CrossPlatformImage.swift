//
//  CrossPlatformImage.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

#if canImport(UIKit)
import UIKit
#endif

import Accelerate.vImage

#if os(macOS)
import Cocoa

/// Alias for making `UIImage` multiplatform.
public typealias UIImage = NSImage

fileprivate extension NSBitmapImageRep {
    func png() -> Data? {
        representation(using: .png, properties: [:])
    }
    
    func jpg(compressionQuality: CGFloat) -> Data? {
        let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: compressionQuality]
        return representation(using: .jpeg, properties: properties)
    }
}

fileprivate extension Data {
    var bitmap: NSBitmapImageRep? {NSBitmapImageRep(data: self)}
}

extension NSImage {
    /// Returns a Core Graphics image based on the contents of the current image object.
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        
        return cgImage(forProposedRect: &proposedRect,
                       context: nil,
                       hints: nil)
    }
    
    /// Returns PNG data based on the contents of the current image object.
    /// - Returns: `Data` containing the PNG conversion of this image.
    func pngData() -> Data? {
        return self.tiffRepresentation?.bitmap?.png()
    }
    
    
    /// Returns JPEG data based on the contents of the current image object.
    /// - Parameter compressionQuality: The quality of the JPEG output.
    /// - Returns: `Data` containing the JPEG conversion of this image.
    func jpegData(compressionQuality: CGFloat) -> Data? {
        return self.tiffRepresentation?.bitmap?.jpg(compressionQuality: compressionQuality)
    }
}

#endif

extension UIImage {
    
    /// Tells whether an image has transparent parts or not.
    /// - Returns: Returns `true` if the image has an available alpha channel, `false` otherwise.
    public func isTransparent() -> Bool {
        guard let alpha: CGImageAlphaInfo = self.cgImage?.alphaInfo else { return false }
        return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }
    
    func scaleWith(newSize: CGSize) -> UIImage? {
        // Decode the source image
        guard let imageSource = CGImageSourceCreateWithDataProvider((self.cgImage?.dataProvider)!, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let imageWidth = properties[kCGImagePropertyPixelWidth] as? vImagePixelCount,
              let imageHeight = properties[kCGImagePropertyPixelHeight] as? vImagePixelCount
        else {
            return nil
        }
        
        // Define the image format
        var format = vImage_CGImageFormat(bitsPerComponent: 8,
                                          bitsPerPixel: 32,
                                          colorSpace: nil,
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                                          version: 0,
                                          decode: nil,
                                          renderingIntent: .defaultIntent)
        
        var error: vImage_Error
        
        // Create and initialize the source buffer
        var sourceBuffer = vImage_Buffer()
        defer { sourceBuffer.data.deallocate() }
        error = vImageBuffer_InitWithCGImage(&sourceBuffer,
                                             &format,
                                             nil,
                                             image,
                                             vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        
        // Create and initialize the destination buffer
        var destinationBuffer = vImage_Buffer()
        error = vImageBuffer_Init(&destinationBuffer,
                                  vImagePixelCount(size.height),
                                  vImagePixelCount(size.width),
                                  format.bitsPerPixel,
                                  vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        
        // Scale the image
        error = vImageScale_ARGB8888(&sourceBuffer,
                                     &destinationBuffer,
                                     nil,
                                     vImage_Flags(kvImageHighQualityResampling))
        guard error == kvImageNoError else { return nil }
        
        // Create a CGImage from the destination buffer
        guard let resizedImage =
                vImageCreateCGImageFromBuffer(&destinationBuffer,
                                              &format,
                                              nil,
                                              nil,
                                              vImage_Flags(kvImageNoAllocate),
                                              &error)?.takeRetainedValue(),
              error == kvImageNoError
        else {
            return nil
        }
        
        return UIImage(cgImage: resizedImage, size: newSize)
    }
}
