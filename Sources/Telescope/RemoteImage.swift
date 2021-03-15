//
//  RemoteImage.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Represents an image that is loaded from a remote resource path.
public class RemoteImage {
    
    // MARK: - Initializers
    
    /// Initializes a new remote image from an `URL`.
    /// - Parameters:
    ///   - url: The image URL.
    public init(imageURL url: URL) {
        self.url = url
    }
    
    /// Initializes a new remote image with a `String` representation of the URL.
    /// - Parameter stringURL: The image URL in a `String` form.
    /// - Throws: `RemoteImageError.invalidURL` if the URL can't be parsed.
    public convenience init?(stringURL: String) throws {
        guard let url = URL(string: stringURL) else {
            throw RemoteImageError.invalidURL(stringURL: stringURL)
        }
        
        self.init(imageURL: url)
    }
    
    // MARK: - Properties
    
    /// Set to true if the last loading of the image threw an error.
    private(set) var hasLoadingError: Bool = false
    
    /// The local caching system for this instance of `RemoteImage`.
    public var cache: Cache = TelescopeImageCache.shared
    
    /// The remote `URL` of the image.
    private(set) var url: URL
    
    // MARK: - Methods
    
    // TODO: public func getOriginalImage
    
    /// Preloads the image right now.
    /// - Throws: Errors coming from the caching system. Depends on the system chosen.
    /// - Returns: This `RemoteImage` instance, but preloaded.
    /// - Warning: This is a **blocking** method!
    public func preload() throws -> RemoteImage {
        let s = DispatchSemaphore(value: 0)
        hasLoadingError = false
        self.cache.get(self.url, completion: { image, error in
            if error != nil {
                self.hasLoadingError = true
            }
            
            s.signal()
        })
        
        s.wait()
        return self
    }
    
    /// Returns the enclosed image, getting it from the nearest source.
    /// - Parameter completion: Completion handler.
    /// - Parameter withSize: The desired size of the image after scaling. The image will be cached with this size. If `nil`, no scaling will happen.
    /// - Throws: Errors coming from the caching system. Depends on the system chosen.
    /// - Note: The resulting `UIImage` does not necessarily have the specified size, rather, it will have the largest size fitting the specified frame.
    /// - Note: The image might not get scaled when the computed reduction ratio is just above 1
    public func image(/*withSize: CGSize,*/ completion: @escaping (UIImage?) -> Void) throws {
        hasLoadingError = false
        self.cache.get(self.url) { image, error in
            if let i = image {
                completion(i)
                return
            }
            
            if error != nil {
                self.hasLoadingError = true
            }
        }
    }
    
    /// Edits the original image
    /// - Parameter newImage: The edited image.
    /// - Throws: Errors coming from the caching system. Depends on the system chosen.
    public func editOriginal(newImage: UIImage) throws {
        try self.cache.edit(self.url, new: newImage, saveWith: nil)
    }
    
    // MARK: - Subscript
    
    /// Access a tagged image related to this instance.
    public subscript(index: String) -> UIImage? {
        get {
            do {
                hasLoadingError = false
                return try self.cache.get(self.url, with: index)
            } catch {
                hasLoadingError = true
                return nil
            }
        }
        
        set(newValue) {
            if let i = newValue {
                try? self.cache.edit(self.url, new: i, saveWith: index)
            }
        }
    }
}
