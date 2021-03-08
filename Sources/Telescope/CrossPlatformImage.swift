//
//  CrossPlatformImage.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

#if os(macOS)
import Cocoa

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
    func jpgData(compressionQuality: CGFloat) -> Data? {
        return self.tiffRepresentation?.bitmap?.jpg(compressionQuality: compressionQuality)
    }
}

#endif

extension UIImage {
    public func isTransparent() -> Bool {
        guard let alpha: CGImageAlphaInfo = self.cgImage?.alphaInfo else { return false }
        return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }
}
