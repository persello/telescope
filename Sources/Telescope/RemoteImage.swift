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
    private var image: UIImage?
    private(set) var editTags: Set<String> = []
    private(set) var url: URL
    public var cache: Cache = TelescopeImageCache.shared
    
    // MARK: - Methods
    public func preload() throws -> RemoteImage {
        self.image = try self.cache.get(self.url)
        return self
    }
    
    public func saveEdited(new image: UIImage, tag: String) {
        
    }
    
    // MARK: - Subscript
//    subscript(index: String) -> UIImage {
//        get {
//            
//        }
//        
//        set(newValue) {
//            saveEdited(new: newValue, tag: index)
//        }
//    }
}
