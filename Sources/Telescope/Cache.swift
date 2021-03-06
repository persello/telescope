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

public protocol Cache {
    
    /// Get the `UIImage` of this `RemoteImage` from the fastest source.
    /// - Parameter : The `RemoteImage` object to lookup.
    func get(_: RemoteImage) -> UIImage
    
    
    /// Get the edited version of this `RemoteImage` identified by the specified tag.
    /// - Parameters:
    ///   - : The `RemoteImage` object to consider.
    ///   - tag: The edit tag for looking up the requested image.
    func get(_: RemoteImage, with tag: String) -> UIImage
    func delete(_: RemoteImage)
    func deleteAll(_: RemoteImage)
    func refresh(_: RemoteImage)
    func refreshAll()
    func edit(_: RemoteImage, saveWith tag: String)
}

class TelescopeImageCache: Cache {
    
    // MARK: - Initializers
    init() {
        volatileCache.countLimit = 100
    }
    
    // MARK: - Static
    static public var refreshTime: TimeInterval = 5 * 24 * 60 * 60
    
    // MARK: - Properties
    private var volatileCache = NSCache<NSString, UIImage>()
    
    // MARK: - Private functions
    private func getFromVolatileCache(remoteImage: RemoteImage, tag: String?) -> UIImage? {
        volatileCache.object(forKey: "\((remoteImage.url.absoluteString + (tag ?? "")).MD5())" as NSString)
    }
    
    private func getFromFileCache(remoteImage: RemoteImage, tag: String?) -> UIImage? {
        
    }
    
    private func saveToVolatileCache(remoteImage: RemoteImage, image: UIImage, tag: String?) {
        volatileCache.setObject(image, forKey: "\((remoteImage.url.absoluteString + (tag ?? "")).MD5())" as NSString)
    }
    
    private func saveToFileCache(remoteImage: RemoteImage, image: UIImage, tag: String?) {
        
    }
    
    private func download(remoteImage: RemoteImage) -> UIImage {
        
    }
    
    
    // MARK: - Public protocol implementation
    func get(_: RemoteImage) -> UIImage {
//        <#code#>
    }
    
    func get(_: RemoteImage, with tag: String) -> UIImage {
//        <#code#>
    }
    
    func delete(_: RemoteImage) {
//        <#code#>
    }
    
    func deleteAll(_: RemoteImage) {
//        <#code#>
    }
    
    func refresh(_: RemoteImage) {
//        <#code#>
    }
    
    func refreshAll() {
//        <#code#>
    }
    
    func edit(_: RemoteImage, saveWith tag: String) {
//        <#code#>
    }
}

/*
 let i = RemoteImage("https://bap.com/a.jpg")
 i.saveEdited(UIImage, "edit1") = i["edit1"] = UIImage
 let originalImage = i() = i.image
 let editedImage = i["edit1"]
 */
