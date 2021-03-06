//
//  CrossPlatformImage.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

#if os(macOS)
import Cocoa

public typealias UIImage = NSImage

extension NSBitmapImageRep {
    var png: Data? { representation(using: .png, properties: [:])}
    func jpg(compressionQuality: CGFloat) -> Data? {
        let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: compressionQuality]
        return representation(using: .jpeg, properties: properties)
    }
}

extension Data {
    var bitmap: NSBitmapImageRep? {NSBitmapImageRep(data: self)}
}

extension NSImage {
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        
        return cgImage(forProposedRect: &proposedRect,
                       context: nil,
                       hints: nil)
    }
    
    func pngData() -> Data? {
        return self.tiffRepresentation?.bitmap?.png
    }
    
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
