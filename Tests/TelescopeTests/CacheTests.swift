//
//  CacheTests.swift
//  TelescopeTests
//
//  Created by Riccardo Persello on 06/03/21.
//

import XCTest
@testable import Telescope

class CacheTests: XCTestCase {
    
    var sut: TelescopeImageCache!
    
    override func setUpWithError() throws {
        sut = try TelescopeImageCache()
        try sut.deleteAll()
    }

    override func tearDownWithError() throws {
        sut = nil
    }
    
    func testSharedExists() {
        XCTAssertNotNil(TelescopeImageCache.shared, "Shared `TelescopeImageCache` is nil.")
    }

    func testZeroFiles() {
        // At maximum the index file
        XCTAssert(sut.imagesInFiles.count <= 1, "Starting with non-empty image file index.")
        XCTAssert(try FileManager.default.contentsOfDirectory(at: sut.fileCacheFolder, includingPropertiesForKeys: nil).count <= 1, "Starting with non-empty cache folder.")
    }
    
    func requestImageURL(color: Int) -> URL {
        return URL(string: "https://dummyimage.com/250/\(String(format: "%02x", color))/000000")!
    }
    
    func testSaveImages() {
        measure {
            DispatchQueue.concurrentPerform(iterations: 200) { (i) in
                var image: UIImage!
                XCTAssertNoThrow(image = try! self.sut.get(requestImageURL(color: i)), "Exception while getting image #\(i).")
                XCTAssertNotNil(image, "Image \(i) is nil. ")
            }
        }
    }

}
