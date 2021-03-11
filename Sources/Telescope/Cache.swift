//
//  Cache.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

import Foundation
import CryptoKit
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

#if os(watchOS)
#error("watchOS is not supported!")
#endif

extension String {
    
    /// Computes the MD5 checksum for the current `String`.
    /// - Returns: A fixed length `String` containing the MD5.
    func MD5() -> String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
}

/// A policy for choosing the best file format when storing images in the file cache.
public enum FileFormatPolicy {
    
    /// Always store images as PNG (more memory and storage use).
    case alwaysPNG
    
    /// Only store images in PNG format when they have an alpha channel, otherwise use JPG.
    /// - Parameter jpgQuality: The compression quality of the image when stored to JPG.
    case PNGWhenTransparent(jpgQuality: CGFloat)
    
    /// Always store images as JPG.
    /// - Parameter jpgQuality: The compression quality of the stored image.
    /// - Attention : With this setting, you will **always** lose the transparency of the image when it will get reloaded from file.
    case alwaysJPG(jpgQuality: CGFloat)
}

// MARK: - Protocol

/// A protocol for defining a caching system of remote images.
public protocol Cache {
    
    /// Get the `UIImage` of this `URL` from the fastest source.
    /// - Parameter imageURL: The `URL` object to lookup.
    /// - Parameter completion: Completion handler.
    func get(_ imageURL: URL, completion: @escaping (UIImage) -> Void) throws

    
    /// Get the edited version of this `URL` identified by the specified tag.
    /// - Parameters:
    ///   - imageURL: The `URL` object to consider.
    ///   - tag: The edit tag for looking up the requested image.
    func get(_ imageURL: URL, with tag: String) throws -> UIImage
    
    /// Deletes the image with specified `URL` and tag from the entire caching system.
    /// - Parameters:
    ///   - imageURL: The original image's `URL`.
    ///   - tag: The specific tagged edit to delete.
    func delete(_ imageURL: URL, tag: String?) throws
    
    /// Deletes all the images from the entire caching system.
    func deleteAll() throws
    
    /// Refreshes the specified image.
    /// - Parameter imageURL: The original URL of the image.
    /// - Remark: Obviously, an edited image can't be refreshed.
    func refresh(_ imageURL: URL) throws
    
    /// Refreshes all the original images stored as files.
    func refreshAll() throws
    
    /// Saves an edited version of an image with the specified tag.
    /// - Parameters:
    ///   - imageURL: The original image's URL.
    ///   - image: The edited image.
    ///   - tag: The tag to use for saving the edited image.
    func edit(_ imageURL: URL, new image: UIImage, saveWith tag: String) throws
    
    /// The refresh time interval after the images should be refetched from source.
    var refreshTime: TimeInterval { get }
    
    /// The folder to use for saving the images as cache files and other related files.
    var fileCacheFolder: URL { get }
    
    /// The policy to use for choosing which format to use when saving an image to a file.
    var fileFormatPolicy: FileFormatPolicy { get }
}

/// The default Telescope image caching system.
class TelescopeImageCache: Cache {
    
    // MARK: - Initializer
    
    /// Initializes a new instance of `TelescopeImageCache`.
    /// - Parameters:
    ///   - file: The file used for preloading dictionary data.
    ///   - time: A `TimeInterval` to specify the refresh period of the stored images.
    ///   - cacheFolder: The folder to use for saving the cached images and dictionary (if not set via the `file` parameter).
    ///   - formatPolicy: The policy to use for choosing which format to use when saving an image to a file.
    /// - Throws: `JSONSerialization` related errors when loading an invalid JSON-serialized dictionary. `FileManager` related errors when trying to create or access an invalid folder.
    init(from file: URL? = nil,
         refreshTime time: TimeInterval = 5 * 24 * 60 * 60,
         cacheFolder: URL = FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask).first!.appendingPathComponent("TelescopeCache"),
         formatPolicy: FileFormatPolicy = .PNGWhenTransparent(jpgQuality: 0.7)) throws {
        
        // Load dictionary from plist
        databaseFile = (file == nil) ?
            cacheFolder.appendingPathComponent("telescope.json") :
            file!
        
        if let data = try? Data(contentsOf: databaseFile) {
            imagesInFiles = try JSONSerialization.jsonObject(with: data, options: []) as! [NSString : String]
        }
        
        // Set refresh time
        refreshTime = time
        
        // Set cache folder
        if !FileManager.default.fileExists(atPath: cacheFolder.absoluteString) {
            try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true, attributes: nil)
        }
        
        fileCacheFolder = cacheFolder
        
        // Set format policy
        fileFormatPolicy = formatPolicy
    }
    
    // MARK: - Properties
    
    /// The `URL` pointing to the dictionary file.
    internal var databaseFile: URL
    
    /// The volatile image cache.
    internal var volatileCache = NSCache<NSString, UIImage>()
    
    /// A dictionary containing all the images' URLs as `String`s, keyed by their MD5.
    internal var imagesInFiles = Dictionary<NSString, String>() {
        didSet {
            let jsonData = try! JSONSerialization.data(withJSONObject: imagesInFiles, options: [])
            try! jsonData.write(to: databaseFile)
        }
    }
    
    /// A queue for managing atomic access to the dictionary.
    private let dictionaryQueue = DispatchQueue(label: "CacheDictionaryQueue")
    
    /// The refresh time interval for the pictures in this cache. Set to zero for no refresh.
    private(set) var refreshTime: TimeInterval
    
    /// The cache folder for storing images (and the dictionary if not differently specified).
    private(set) var fileCacheFolder: URL
    
    /// The file cache format policy.
    private(set) var fileFormatPolicy: FileFormatPolicy
    
    
    /// A shared instance of the Telescope default caching system.
    static public let shared = try! TelescopeImageCache()
    
    // MARK: - Private functions
    
    /// Transforms two concatenated strings in their MD5.
    /// - Parameters:
    ///   - name: Usually the name or the URL of an image.
    ///   - tag: Usually the tag of an edit for the image specified by the previous parameter.
    /// - Returns: The MD5 as an `NSString`.
    private func transform(input name: String, tag: String? = nil) -> NSString {
        return (name + (tag ?? "")).MD5() as NSString
    }
    
    /// Transforms two concatenated strings in their MD5.
    /// - Parameters:
    ///   - name: Usually the name or the URL of an image.
    ///   - tag: Usually the tag of an edit for the image specified by the previous parameter.
    /// - Returns: The MD5 as a `String`.
    private func transform(input name: String, tag: String? = nil) -> String {
        return (name + (tag ?? "")).MD5()
    }
    
    /// Gets an `UIImage` from the `NSCache` by its URL and edit tag.
    /// - Parameters:
    ///   - imageURL: The original image's URL.
    ///   - tag: An edit tag.
    /// - Returns: The requested `UIImage` when found in the volatile cache, otherwise `nil`.
    private func getFromVolatileCache(imageURL: URL, tag: String? = nil) -> UIImage? {
        volatileCache.object(forKey: transform(input: imageURL.absoluteString, tag: tag))
    }
    
    /// Gets an `UIImage` from the file cache by its URL and edit tag. Refreshes the file if necessary but doesn't throw if it fails.
    /// - Parameters:
    ///   - imageURL: The original image's URL.
    ///   - tag: An edit tag.
    /// - Returns: The requested `UIImage` when found in the file cache, otherwise `nil`.
    private func getFromFileCache(imageURL: URL, tag: String? = nil) -> UIImage? {
        let filename = fileCacheFolder.appendingPathComponent(transform(input: imageURL.absoluteString, tag: tag))
        
        if refreshTime > 0 && tag == nil {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: filename.absoluteString) as NSDictionary {
                if let fileDate = attrs.fileCreationDate() {
                    if abs(fileDate.timeIntervalSinceNow) > refreshTime {
                        try? refresh(imageURL)
                    }
                }
            }
        }
        
        if let image = UIImage(contentsOfFile: filename.path) {
            return image
        }
        
        return nil
    }
    
    /// Saves an `UIImage` to the `NSCache`.
    /// - Parameters:
    ///   - imageURL: The original image's URL.
    ///   - image: The image object.
    ///   - tag: An edit tag.
    private func saveToVolatileCache(imageURL: URL, image: UIImage, tag: String? = nil) {
        volatileCache.setObject(image, forKey: transform(input: imageURL.absoluteString, tag: tag))
    }
    
    /// Saves an `UIImage` to the file cache.
    /// - Parameters:
    ///   - imageURL: The original image's URL.
    ///   - image: The image object.
    ///   - tag: An edit tag.
    /// - Throws: `Data` writing errors when it's impossible to create or update a file.
    private func saveToFileCache(imageURL: URL, image: UIImage, tag: String? = nil) throws {
        var data: Data?
        switch fileFormatPolicy {
            case .alwaysPNG:
                data = image.pngData()
            case .PNGWhenTransparent(jpgQuality: let jpgQuality):
                data = image.isTransparent() ? image.pngData() : image.jpegData(compressionQuality: jpgQuality)
            case .alwaysJPG(jpgQuality: let jpgQuality):
                data = image.jpegData(compressionQuality: jpgQuality)
        }
        
        let filename = fileCacheFolder.appendingPathComponent(transform(input: imageURL.absoluteString, tag: tag))
        try data?.write(to: filename)
        dictionaryQueue.sync {
            imagesInFiles[transform(input: imageURL.absoluteString, tag: tag)] = (tag == nil) ? imageURL.absoluteString : ""
        }
    }
    
    /// Deletes an `UIImage` from the `NSCache`.
    /// - Parameters:
    ///   - imageURL: The original image's URL.
    ///   - tag: An edit tag.
    private func deleteFromVolatileCache(imageURL: URL, tag: String? = nil) {
        volatileCache.removeObject(forKey: transform(input: imageURL.absoluteString, tag: tag))
    }
    
    /// Deletes an `UIImage` from the file cache.
    /// - Parameters:
    ///   - imageURL: The original image's URL.
    ///   - tag: An edit tag.
    private func deleteFromFileCache(imageURL: URL, tag: String? = nil) {
        
        // Should not throw an exception because the file could have been already removed by the system.
        try? FileManager.default.removeItem(at: fileCacheFolder.appendingPathComponent(
            transform(input: imageURL.absoluteString,
                      tag:tag)
        ))
        
        dictionaryQueue.sync {
            _ = imagesInFiles.removeValue(forKey: transform(input: imageURL.absoluteString, tag: tag))
        }
    }
    
    /// Deletes all the contents of the `NSCache`.
    private func cleanVolatileCache() {
        volatileCache.removeAllObjects()
    }
    
    /// Deletes all contents from the file cache folder.
    /// - Throws: `FileManager` related errors when it's impossible to access the cache folder or to delete a contained file.
    /// - Warning: It could also delete the stored serialized dictionary, but it shouldn't matter since all images are being deleted.
    private func cleanFileCache() throws {
        
        // Also could delete the stored dictionary, but it's not important.
        let paths = try FileManager.default.contentsOfDirectory(at: fileCacheFolder, includingPropertiesForKeys: nil)
        for path in paths {
            try FileManager.default.removeItem(at: path)
        }
        
        dictionaryQueue.sync {
            imagesInFiles.removeAll()
        }
    }
    
    /// Downloads an `UIImage` from the specified `URL` and calls a completion handler when it finishes or an error occurs.
    /// - Parameters:
    ///   - imageURL: The desired image's URL.
    ///   - completion: The closure called on completion or error.
    ///   - image: When successful, the requested image, when an error occurs, `nil`.
    ///   - error: `nil` when successful, otherwise an `URLSession`-related error or a `RemoteImageError`.
    private func download(imageURL: URL, completion: @escaping (_ image: UIImage?, _ error: Error?) -> Void) {
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(nil, RemoteImageError.httpError(url: imageURL, code: (response as? HTTPURLResponse)?.statusCode ?? 0))
                return
            }
            
            if let data = data {
                if let image = UIImage(data: data) {
                    completion(image, nil)
                    return
                } else {
                    completion(nil, RemoteImageError.notAnImage(url: imageURL))
                }
            }
        }
        .resume()
    }
    
    
    // MARK: - Public protocol implementation
    
    /// Get the `UIImage` of this `URL` from the fastest source.
    /// - Parameter imageURL: The `URL` object to lookup.
    /// - Parameter completion: Completion handler.
    /// - Throws: `URLSession`-related error or a `RemoteImageError`.
    func get(_ imageURL: URL, completion: @escaping (UIImage) -> Void) throws {
        
        // Get from NSCache, fastest
        if let image = getFromVolatileCache(imageURL: imageURL) {
            completion(image)
        }
        
        // Get from file, if successful, save to NSCache
        if let image = getFromFileCache(imageURL: imageURL) {
            saveToVolatileCache(imageURL: imageURL, image: image)
            completion(image)
        }
        
        // Download, if successful save to both caches
        var closureError: Error?
        
        download(imageURL: imageURL) { [self] image, error in
            
            if let e = error {
                closureError = e
                return
            }
            
            if let i = image {
                do {
                    try saveToFileCache(imageURL: imageURL, image: i)
                    saveToVolatileCache(imageURL: imageURL, image: i)
                    completion(i)
                } catch {
                    closureError = error
                }
            }
        }
        
        if let ce = closureError {
            throw ce
        }
    }
    
    /// Get the `UIImage` of this `URL` from the fastest source.
    /// - Parameters:
    ///   - imageURL: The `URL` object to consider.
    ///   - tag: The edit tag for looking up the requested image.
    /// - Throws: `URLSession`-related error or a `RemoteImageError`.
    /// - Returns: The downloaded or locally fetched `UIImage`.
    func get(_ imageURL: URL, with tag: String) throws -> UIImage {
        if let image = getFromVolatileCache(imageURL: imageURL, tag: tag) {
            return image
        }
        
        if let image = getFromFileCache(imageURL: imageURL, tag: tag) {
            saveToVolatileCache(imageURL: imageURL, image: image, tag: tag)
            return image
        }
        
        throw RemoteImageError.editNotFound(tag: tag)
    }
    
    /// Deletes the image with specified `URL` and tag from the entire caching system.
    /// - Parameters:
    ///   - imageURL: The original image's `URL`.
    ///   - tag: The specific tagged edit to delete.
    func delete(_ imageURL: URL, tag: String? = nil) {
        deleteFromVolatileCache(imageURL: imageURL)
        deleteFromFileCache(imageURL: imageURL)
    }
    
    /// Deletes all the images from the entire caching system.
    /// - Throws: `FileManager` related errors when it’s impossible to access the cache folder or to delete a contained file.
    func deleteAll() throws {
        cleanVolatileCache()
        try cleanFileCache()
    }
    
    /// Refreshes the specified image.
    /// - Parameter imageURL: The original URL of the image.
    /// - Remark: Obviously, an edited image can't be refreshed.
    /// - Throws: `URLSession`-related error or a `RemoteImageError`.
    func refresh(_ imageURL: URL) throws {
        delete(imageURL)
        try get(imageURL, completion: {image in})
    }
    
    /// Refreshes all the original images stored as files.
    /// - Throws: `URLSession`-related error or a `RemoteImageError`.
    func refreshAll() throws {
        for entry in imagesInFiles {
            if let url = URL(string: entry.value) {
                try refresh(url)
            }
        }
    }
    
    /// Saves an edited version of an image with the specified tag.
    /// - Parameters:
    ///   - imageURL: The original image's URL.
    ///   - image: The edited image.
    ///   - tag: The tag to use for saving the edited image.
    /// - Throws: `Data` writing errors when it’s impossible to create or update a file.
    func edit(_ imageURL: URL, new image: UIImage, saveWith tag: String) throws {
        try saveToFileCache(imageURL: imageURL, image: image, tag: tag)
        saveToVolatileCache(imageURL: imageURL, image: image, tag: tag)
    }
}
