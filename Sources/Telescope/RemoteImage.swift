//
//  RemoteImage.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

import Foundation


/// Represents an image that is loaded from a remote resource path.
public class RemoteImage {
    
    // MARK: - Initializers
    
    /// Initializes a new remote image from an `URL`.
    /// - Parameters:
    ///   - url: The image URL.
    init(imageURL url: URL) {
        self.url = url
    }
    
    /// Initializes a new remote image with a `String` representation of the URL.
    /// - Parameter stringURL: The image URL in a `String` form.
    /// - Throws: `RemoteImageError.invalidURL` if the URL can't be parsed.
    convenience init?(stringURL: String) throws {
        guard let url = URL(string: stringURL) else {
            throw RemoteImageError.invalidURL(stringURL: stringURL)
        }
        
        self.init(imageURL: url)
    }
        
    // MARK: - Properties
    private var preloadedImage: UIImage?
    private(set) var url: URL
    
    public var cache: Cache = TelescopeImageCache.shared
    
    // MARK: - Methods
    public func preload() throws -> RemoteImage {
        self.preloadedImage = try self.cache.get(self.url)
        return self
    }
    
    public func image() throws -> UIImage? {
        if let i = self.preloadedImage {
            return i
        }
        
        return try self.cache.get(self.url)
    }

    // MARK: - Subscript
    subscript(index: String) -> UIImage? {
        get {
            try? self.cache.get(self.url, with: index)
        }
        
        set(newValue) {
            if let i = newValue {
                try? self.cache.edit(self.url, new: i, saveWith: index)
            }
        }
    }
}
