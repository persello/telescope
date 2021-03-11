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
    
    /// Set by the `preload()` method.
    private var preloadedImage: UIImage?
    
    /// Set to true if the last loading of the image threw an error.
    private(set) var hasLoadingError: Bool = false
    
    /// The local caching system for this instance of `RemoteImage`.
    public var cache: Cache = TelescopeImageCache.shared
    
    /// The remote `URL` of the image.
    private(set) var url: URL
    
    // MARK: - Methods
    
    /// Preloads the image right now.
    /// - Throws: Errors coming from the caching system. Depends on the system chosen.
    /// - Returns: This `RemoteImage` instance, but preloaded.
    /// - Warning: This is a **blocking** method!
    public func preload() throws -> RemoteImage {
        do {
            let s = DispatchSemaphore(value: 0)
            hasLoadingError = false
            try self.cache.get(self.url, completion: { image in
                defer { s.signal() }
                self.preloadedImage = image
            })
            
            s.wait()
            return self
        } catch {
            hasLoadingError = true
            throw error
        }
    }
    
    /// Returns the enclosed image, getting it from the nearest source.
    /// - Throws: Errors coming from the caching system. Depends on the system chosen.
    /// - Parameter completion: Completion handler.
    public func image(completion: @escaping (UIImage?) -> Void) throws {
        if let i = self.preloadedImage {
            hasLoadingError = false
            completion(i)
        }
        
        do {
            hasLoadingError = false
            try self.cache.get(self.url, completion: completion)
        } catch {
            hasLoadingError = true
            throw error
        }
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
