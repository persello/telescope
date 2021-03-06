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
    
    /// Get the `UIImage` of this `RemoteImage` from the fastest source.
    /// - Parameter : The `RemoteImage` object to lookup.
    func get(_ remoteImage: RemoteImage) throws -> UIImage
    
    
    /// Get the edited version of this `RemoteImage` identified by the specified tag.
    /// - Parameters:
    ///   - : The `RemoteImage` object to consider.
    ///   - tag: The edit tag for looking up the requested image.
    func get(_ remoteImage: RemoteImage, with tag: String) throws -> UIImage
    func delete(_ remoteImage: RemoteImage, tag: String?) throws
    func deleteAll(_ remoteImage: RemoteImage) throws
    func refresh(_ remoteImage: RemoteImage) throws
    func refreshAll() throws
    func edit(_ remoteImage: RemoteImage, new image: UIImage, saveWith tag: String) throws
    
    var refreshTime: TimeInterval { get }
    var fileCacheFolder: URL { get }
    var fileFormatPolicy: FileFormatPolicy { get }
}

class TelescopeImageCache: Cache {
        
    // MARK: - Initializers
    init(from file: URL? = nil,
         refreshTime time: TimeInterval = 5 * 24 * 60 * 60,
         cacheFolder: URL = FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask).first!,
         formatPolicy: FileFormatPolicy = .PNGWhenTransparent(jpgQuality: 0.7)) throws {
        
        // Load dictionary from plist
        databaseFile = (file == nil) ?
            FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask).first!.appendingPathComponent("telescope.plist") :
            file!
        
        if let data = try? Data(contentsOf: databaseFile) {
            imagesInFiles = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! [NSString : RemoteImage]
        }
        
        // Set refresh time
        refreshTime = time
        
        // Set cache folder
        fileCacheFolder = cacheFolder
        
        // Set format policy
        fileFormatPolicy = formatPolicy
    }
    
    // MARK: - Properties
    private var databaseFile: URL
    private var volatileCache = NSCache<NSString, UIImage>()
    private var imagesInFiles = Dictionary<NSString, RemoteImage>() {
        didSet {
            try! NSKeyedArchiver.archivedData(withRootObject: imagesInFiles, requiringSecureCoding: false)
                .write(to: databaseFile)
        }
    }
    
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
    
    private func getFromVolatileCache(remoteImage: RemoteImage, tag: String? = nil) -> UIImage? {
        volatileCache.object(forKey: transform(input: remoteImage.url.absoluteString, tag: tag))
    }
    
    private func getFromFileCache(remoteImage: RemoteImage, tag: String? = nil) -> UIImage? {
        let filename = fileCacheFolder.appendingPathComponent(transform(input: remoteImage.url.absoluteString, tag: tag))
        if let image = UIImage(contentsOfFile: filename.path) {
            return image
        }
        
        return nil
    }
    
    private func saveToVolatileCache(remoteImage: RemoteImage, image: UIImage, tag: String? = nil) {
        volatileCache.setObject(image, forKey: transform(input: remoteImage.url.absoluteString, tag: tag))
    }
    
    private func saveToFileCache(remoteImage: RemoteImage, image: UIImage, tag: String? = nil) throws {
        var data: Data?
        switch fileFormatPolicy {
            case .alwaysPNG:
                data = image.pngData()
            case .PNGWhenTransparent(jpgQuality: let jpgQuality):
                data = image.isTransparent() ? image.pngData() : image.jpgData(compressionQuality: jpgQuality)
            case .alwaysJPG(jpgQuality: let jpgQuality):
                data = image.jpgData(compressionQuality: jpgQuality)
        }
        
        let filename = fileCacheFolder.appendingPathComponent(transform(input: remoteImage.url.absoluteString, tag: tag))
        try data?.write(to: filename)
        imagesInFiles[transform(input: remoteImage.url.absoluteString, tag: tag)] = remoteImage
    }
    
    private func deleteFromVolatileCache(remoteImage: RemoteImage, tag: String? = nil) {
        volatileCache.removeObject(forKey: transform(input: remoteImage.url.absoluteString, tag: tag))
    }
    
    private func deleteFromFileCache(remoteImage: RemoteImage, tag: String? = nil) {
        
        // Should not throw an exception because the file could have been already removed by the system.
        try? FileManager.default.removeItem(at: fileCacheFolder.appendingPathComponent(
            transform(input: remoteImage.url.absoluteString,
                      tag:tag)
        ))
        
        imagesInFiles.removeValue(forKey: transform(input: remoteImage.url.absoluteString, tag: tag))
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
        
        imagesInFiles.removeAll()
    }
    
    private func download(remoteImage: RemoteImage, completion: @escaping (UIImage?, Error?) -> Void) {
        URLSession.shared.dataTask(with: remoteImage.url) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(nil, RemoteImageError.httpError(url: remoteImage.url, code: (response as? HTTPURLResponse)?.statusCode ?? 0))
                return
            }
            
            if let data = data {
                if let image = UIImage(data: data) {
                    completion(image, nil)
                    return
                } else {
                    completion(nil, RemoteImageError.notAnImage(url: remoteImage.url))
                }
            }
        }
        .resume()
    }
    
    
    // MARK: - Public protocol implementation
    func get(_ remoteImage: RemoteImage) throws -> UIImage {
        
        // Get from NSCache, fastest
        if let image = getFromVolatileCache(remoteImage: remoteImage) {
            return image
        }
        
        // Get from file, if successful, save to NSCache
        if let image = getFromFileCache(remoteImage: remoteImage) {
            saveToVolatileCache(remoteImage: remoteImage, image: image)
            return image
        }
        
        // Download, if successful save to both caches
        let semaphore = DispatchSemaphore(value: 0)
        var closureError: Error?
        var closureImage: UIImage?
        
        download(remoteImage: remoteImage) { image, error in
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
            try saveToFileCache(remoteImage: remoteImage, image: i)
            saveToVolatileCache(remoteImage: remoteImage, image: i)
            return i
        } else {
            throw RemoteImageError.unknown
        }
    }
    
    func get(_ remoteImage: RemoteImage, with tag: String) throws -> UIImage {
        if let image = getFromVolatileCache(remoteImage: remoteImage, tag: tag) {
            return image
        }
        
        if let image = getFromFileCache(remoteImage: remoteImage, tag: tag) {
            saveToVolatileCache(remoteImage: remoteImage, image: image, tag: tag)
            return image
        }
        
        throw RemoteImageError.editNotFound(remoteImage: remoteImage, tag: tag)
    }
    
    func delete(_ remoteImage: RemoteImage, tag: String? = nil) {
        deleteFromVolatileCache(remoteImage: remoteImage)
        deleteFromFileCache(remoteImage: remoteImage)
    }
    
    func deleteAll(_ remoteImage: RemoteImage) throws {
        cleanVolatileCache()
        try cleanFileCache()
    }
    
    func refresh(_ remoteImage: RemoteImage) throws {
        delete(remoteImage)
        _ = try get(remoteImage)
    }
    
    func refreshAll() throws {
        for image in imagesInFiles {
            try refresh(image.value)
        }
    }
    
    func edit(_ remoteImage: RemoteImage, new image: UIImage, saveWith tag: String) throws {
        try saveToFileCache(remoteImage: remoteImage, image: image, tag: tag)
        saveToVolatileCache(remoteImage: remoteImage, image: image, tag: tag)
    }
}

/*
 let i = RemoteImage("https://bap.com/a.jpg")
 i.saveEdited(UIImage, "edit1") = i["edit1"] = UIImage
 let originalImage = i() = i.image
 let editedImage = i["edit1"]
 */
