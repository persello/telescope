//
//  RemoteImage.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

import Foundation

public class RemoteImage {
    
    // MARK: - Initializers
    
    /// Initializes a new remote image from an `URL`.
    /// - Parameters:
    ///   - url: The image URL.
    ///   - lazy: Whether the image should be loaded immediately or not. Defaults to lazy.
    init(imageURL url: URL, isLazy lazy: Bool = true) {
        self.url = url
        self.isLazy = lazy
    }
    
    /// Initializes a new remote image with a `String` representation of the URL.
    /// - Parameters:
    ///   - stringURL: The image URL in a `String` form.
    ///   - lazy: Whether the image should be loaded immediately or not. Defaults to lazy.
    /// - Throws: `RemoteImageError.invalidURL` if the URL can't be parsed.
    convenience init?(stringURL: String, isLazy lazy: Bool = true) throws {
        guard let url = URL(string: stringURL) else {
            throw RemoteImageError.invalidURL(stringURL: stringURL)
        }
        
        self.init(imageURL: url, isLazy: lazy)
    }
    
    // MARK: - Static settings
    static private var cache: Cache = TelescopeImageCache()
    
    
    // MARK: - Properties
    
    private var image: UIImage?
    private(set) var editTags: Set<String> = []
    private(set) var url: URL
    private var isLazy: Bool
    
    // MARK: - Methods
    public func saveEdited(new image: UIImage, tag: String) {
        
    }
    
    // MARK: - Subscript
    subscript(index: String) -> UIImage {
        get {
            
        }
        
        set(newValue) {
            saveEdited(new: newValue, tag: index)
        }
    }
}
