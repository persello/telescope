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

#if canImport(Cocoa)
import Cocoa
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
    /// - Parameter preferredSize: The preferred `UIImage` size.
    /// - Parameter completion: Completion handler.
    func get(_ imageURL: URL, preferredSize: CGSize?, completion: @escaping (UIImage?, Error?) -> Void)

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
    ///   - tag: The tag to use for saving the edited image. `nil` for original.
    func edit(_ imageURL: URL, new image: UIImage, saveWith tag: String?) throws
    
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
        
        // URLSession queue
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 8
        configuration.timeoutIntervalForResource = 3600
        configuration.waitsForConnectivity = true
        
        sessionQueue.qualityOfService = .userInitiated
        privateURLSession = URLSession(configuration: configuration, delegate: nil, delegateQueue: sessionQueue)
        
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
        
        // Timer
        _ = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(writeUpdates), userInfo: nil, repeats: true)
    }
    
    // MARK: - Properties
    
    /// The `URL` pointing to the dictionary file.
    internal var databaseFile: URL
    
    /// The volatile image cache.
    internal var volatileCache = NSCache<NSString, UIImage>()
    
    /// A dictionary containing all the images' URLs as `String`s, keyed by their MD5.
    internal var imagesInFiles = Dictionary<NSString, String>() {
        didSet {
            dictionaryUpdatedFlag = true
        }
    }
    
    /// A flag that is true when the dictionary has pending writes.
    private var dictionaryUpdatedFlag: Bool = false
    
    /// Writes the dictionary to disk if `dictionaryUpdatedFlag` is `true`.
    @objc func writeUpdates() {
        if dictionaryUpdatedFlag {
            let jsonData = try! JSONSerialization.data(withJSONObject: imagesInFiles, options: [])
            try! jsonData.write(to: databaseFile)
            dictionaryUpdatedFlag = false
        }
    }
        
    private let sessionQueue = OperationQueue()
    private let privateURLSession: URLSession!
    
    /// A queue for managing atomic access to the dictionary.
    private let dictionaryQueue = OperationQueue()
    
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
        dictionaryQueue.addOperation {
            self.imagesInFiles[self.transform(input: imageURL.absoluteString, tag: tag)] = (tag == nil) ? imageURL.absoluteString : ""
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
        
        dictionaryQueue.addOperation {
            _ = self.imagesInFiles.removeValue(forKey: self.transform(input: imageURL.absoluteString, tag: tag))
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
        
        dictionaryQueue.addOperation {
            self.imagesInFiles.removeAll()
        }
    }
    
    /// Downloads an `UIImage` from the specified `URL` and calls a completion handler when it finishes or an error occurs.
    /// - Parameters:
    ///   - imageURL: The desired image's URL.
    ///   - completion: The closure called on completion or error.
    ///   - image: When successful, the requested image, when an error occurs, `nil`.
    ///   - error: `nil` when successful, otherwise an `URLSession`-related error or a `RemoteImageError`.
    private func download(imageURL: URL, completion: @escaping (_ image: UIImage?, _ error: Error?) -> Void) {
        privateURLSession.dataTask(with: imageURL) { data, response, error in
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
                    try? self.edit(imageURL, new: image, saveWith: "originalSize")
                    completion(image, nil)
                    return
                } else {
                    completion(nil, RemoteImageError.notAnImage(url: imageURL))
                }
            }
        }
        .resume()
    }
    
    private func resizeImageIfNeeded(_ image: UIImage, targetSize size: CGSize, imageURL url: URL? = nil) -> UIImage {
        let screenScale: CGFloat
        
        #if os(macOS)
        screenScale = NSScreen.main?.backingScaleFactor ?? 1
        #else
        screenScale = UIScreen.main.scale
        #endif
        
        var imageToResize = image
        
        // Resize image
        
        // Use the largest scaling ratio (less reduction, more quality)
        var scalingRatio: CGFloat = max(size.height / imageToResize.size.height, size.width / imageToResize.size.width)
                
        // With this small change, we actually have large performance gains at a minimum memory cost
        if scalingRatio * screenScale < 1 && scalingRatio * screenScale > 0.75 {
            // Do not resize image if the size difference is too small
            return imageToResize
        } else if scalingRatio * screenScale > 1 {
            // If a size bigger than the image is being asked, try to get the original image from cache
            
            if let url = url {
                if let originalImage = try? get(url, with: "originalSize") {
                    imageToResize = originalImage
                    
                    // Recompute the scaling ratio
                    scalingRatio = max(size.height / imageToResize.size.height, size.width / imageToResize.size.width)
                    
                    if scalingRatio * screenScale > 0.75 {
                        // If the original image is still bigger (or slightly smaller) than the requested size, do not resize it
                        return imageToResize
                    }
                    
                } else {
                    // If the original image can't be fetched from the cache, return the passed one
                    return imageToResize
                }
            } else {
                // If an URL has not been specified, return the passed one
                return imageToResize
            }
        }
        
        return imageToResize.scaleWith(newSize: CGSize(width: imageToResize.size.width * screenScale * scalingRatio, height: imageToResize.size.height * screenScale * scalingRatio)) ?? imageToResize
    }
    
    // MARK: - Public protocol implementation
    
    /// Get the `UIImage` of this `URL` from the fastest source.
    /// - Parameter imageURL: The `URL` object to lookup.
    /// - Parameter completion: Completion handler.
    func get(_ imageURL: URL, preferredSize: CGSize? = nil, completion: @escaping (UIImage? , Error?) -> Void) {
        
        DispatchQueue.global(qos: .background).async {
            
            // Get from NSCache, fastest
            if var image = self.getFromVolatileCache(imageURL: imageURL) {
                if let preferredSize = preferredSize {
                    image = self.resizeImageIfNeeded(image, targetSize: preferredSize, imageURL: imageURL)
                }
                
                DispatchQueue.main.async {
                    completion(image, nil)
                }
                return
            }
            
            // Get from file, if successful, save to NSCache
            if var image = self.getFromFileCache(imageURL: imageURL) {
                if let preferredSize = preferredSize {
                    image = self.resizeImageIfNeeded(image, targetSize: preferredSize, imageURL: imageURL)
                }
                
                self.saveToVolatileCache(imageURL: imageURL, image: image)
                DispatchQueue.main.async {
                    completion(image, nil)
                }
                return
            }
            
            // Download, if successful save to both caches
            var closureError: Error?
            
            self.download(imageURL: imageURL) { [self] image, error in
                
                if let e = error {
                    closureError = e
                    return
                }
                
                if var i = image {
                    do {
                        if let preferredSize = preferredSize {
                            i = resizeImageIfNeeded(i, targetSize: preferredSize, imageURL: imageURL)
                        }
                        
                        try saveToFileCache(imageURL: imageURL, image: i)
                        saveToVolatileCache(imageURL: imageURL, image: i)
                        
                        DispatchQueue.main.async {
                            completion(i, nil)
                        }
                    } catch {
                        closureError = error
                    }
                }
            }
            
            if let ce = closureError {
                DispatchQueue.main.async {
                    completion(nil, ce)
                }
            }
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
        get(imageURL, completion: {image, error in})
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
    /// - Throws: `Data` writing errors when it’s impossible to create or update a file. If `nil`, edit the original image.
    func edit(_ imageURL: URL, new image: UIImage, saveWith tag: String?) throws {
        try saveToFileCache(imageURL: imageURL, image: image, tag: tag)
        saveToVolatileCache(imageURL: imageURL, image: image, tag: tag)
    }
}
