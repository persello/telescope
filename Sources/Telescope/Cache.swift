//
//  Cache.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

import Foundation
import CryptoKit

extension String {
    func MD5() -> String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
}

public enum FileFormatPolicy {
    case alwaysPNG
    case PNGWhenTransparent(jpgQuality: CGFloat)
    case alwaysJPG(jpgQuality: CGFloat)
}

public protocol Cache {
    
    /// Get the `UIImage` of this `URL` from the fastest source.
    /// - Parameter : The `URL` object to lookup.
    func get(_ imageURL: URL) throws -> UIImage
    
    
    /// Get the edited version of this `URL` identified by the specified tag.
    /// - Parameters:
    ///   - : The `URL` object to consider.
    ///   - tag: The edit tag for looking up the requested image.
    func get(_ imageURL: URL, with tag: String) throws -> UIImage
    func delete(_ imageURL: URL, tag: String?) throws
    func deleteAll() throws
    func refresh(_ imageURL: URL) throws
    func refreshAll() throws
    func edit(_ imageURL: URL, new image: UIImage, saveWith tag: String) throws
    
    var refreshTime: TimeInterval { get }
    var fileCacheFolder: URL { get }
    var fileFormatPolicy: FileFormatPolicy { get }
}

class TelescopeImageCache: Cache {
        
    // MARK: - Initializers
    init(from file: URL? = nil,
         refreshTime time: TimeInterval = 5 * 24 * 60 * 60,
         cacheFolder: URL = FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask).first!.appendingPathComponent("TelescopeCache"),
         formatPolicy: FileFormatPolicy = .PNGWhenTransparent(jpgQuality: 0.7)) throws {
        
        // Load dictionary from plist
        databaseFile = (file == nil) ?
            FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask).first!.appendingPathComponent("TelescopeCache/telescope.json") :
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
    internal var databaseFile: URL
    internal var volatileCache = NSCache<NSString, UIImage>()
    internal var imagesInFiles = Dictionary<NSString, String>() {
        didSet {
            let jsonData = try! JSONSerialization.data(withJSONObject: imagesInFiles, options: [])
            try! jsonData.write(to: databaseFile)
        }
    }
    
    private let dictionaryQueue = DispatchQueue(label: "CacheDictionaryQueue")
    private(set) var refreshTime: TimeInterval
    private(set) var fileCacheFolder: URL
    private(set) var fileFormatPolicy: FileFormatPolicy
    
    static public let shared = try! TelescopeImageCache()
    
    // MARK: - Private functions
    private func transform(input name: String, tag: String? = nil) -> NSString {
        return (name + (tag ?? "")).MD5() as NSString
    }
    
    private func transform(input name: String, tag: String? = nil) -> String {
        return (name + (tag ?? "")).MD5()
    }
    
    private func getFromVolatileCache(imageURL: URL, tag: String? = nil) -> UIImage? {
        volatileCache.object(forKey: transform(input: imageURL.absoluteString, tag: tag))
    }
    
    private func getFromFileCache(imageURL: URL, tag: String? = nil) -> UIImage? {
        let filename = fileCacheFolder.appendingPathComponent(transform(input: imageURL.absoluteString, tag: tag))
        if let image = UIImage(contentsOfFile: filename.path) {
            return image
        }
        
        return nil
    }
    
    private func saveToVolatileCache(imageURL: URL, image: UIImage, tag: String? = nil) {
        volatileCache.setObject(image, forKey: transform(input: imageURL.absoluteString, tag: tag))
    }
    
    private func saveToFileCache(imageURL: URL, image: UIImage, tag: String? = nil) throws {
        var data: Data?
        switch fileFormatPolicy {
            case .alwaysPNG:
                data = image.pngData()
            case .PNGWhenTransparent(jpgQuality: let jpgQuality):
                data = image.isTransparent() ? image.pngData() : image.jpgData(compressionQuality: jpgQuality)
            case .alwaysJPG(jpgQuality: let jpgQuality):
                data = image.jpgData(compressionQuality: jpgQuality)
        }
        
        let filename = fileCacheFolder.appendingPathComponent(transform(input: imageURL.absoluteString, tag: tag))
        try data?.write(to: filename)
        dictionaryQueue.sync {
            imagesInFiles[transform(input: imageURL.absoluteString, tag: tag)] = (tag == nil) ? imageURL.absoluteString : ""
        }
    }
    
    private func deleteFromVolatileCache(imageURL: URL, tag: String? = nil) {
        volatileCache.removeObject(forKey: transform(input: imageURL.absoluteString, tag: tag))
    }
    
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
    
    private func cleanVolatileCache() {
        volatileCache.removeAllObjects()
    }
    
    private func cleanFileCache() throws {
        
        // Also deletes default dictionary, but it's not important.
        let paths = try FileManager.default.contentsOfDirectory(at: fileCacheFolder, includingPropertiesForKeys: nil)
        for path in paths {
            try FileManager.default.removeItem(at: path)
        }
        
        dictionaryQueue.sync {
            imagesInFiles.removeAll()
        }
    }
    
    private func download(imageURL: URL, completion: @escaping (UIImage?, Error?) -> Void) {
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
    func get(_ imageURL: URL) throws -> UIImage {
        
        // Get from NSCache, fastest
        if let image = getFromVolatileCache(imageURL: imageURL) {
            return image
        }
        
        // Get from file, if successful, save to NSCache
        if let image = getFromFileCache(imageURL: imageURL) {
            saveToVolatileCache(imageURL: imageURL, image: image)
            return image
        }
        
        // Download, if successful save to both caches
        let semaphore = DispatchSemaphore(value: 0)
        var closureError: Error?
        var closureImage: UIImage?
        
        download(imageURL: imageURL) { image, error in
            defer { semaphore.signal() }
            
            if let e = error {
                closureError = e
            }
            
            if let i = image {
                closureImage = i
            }
        }
        
        semaphore.wait()
        
        if let e = closureError {
            throw e
        }
        
        if let i = closureImage {
            try saveToFileCache(imageURL: imageURL, image: i)
            saveToVolatileCache(imageURL: imageURL, image: i)
            return i
        } else {
            throw RemoteImageError.unknown
        }
    }
    
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
    
    func delete(_ imageURL: URL, tag: String? = nil) {
        deleteFromVolatileCache(imageURL: imageURL)
        deleteFromFileCache(imageURL: imageURL)
    }
    
    func deleteAll() throws {
        cleanVolatileCache()
        try cleanFileCache()
    }
    
    func refresh(_ imageURL: URL) throws {
        delete(imageURL)
        _ = try get(imageURL)
    }
    
    func refreshAll() throws {
        for entry in imagesInFiles {
            if let url = URL(string: entry.value) {
                try refresh(url)
            }
        }
    }
    
    func edit(_ imageURL: URL, new image: UIImage, saveWith tag: String) throws {
        try saveToFileCache(imageURL: imageURL, image: image, tag: tag)
        saveToVolatileCache(imageURL: imageURL, image: image, tag: tag)
    }
}

/*
 let i = URL("https://bap.com/a.jpg")
 i.saveEdited(UIImage, "edit1") = i["edit1"] = UIImage
 let originalImage = i() = i.image
 let editedImage = i["edit1"]
 */
