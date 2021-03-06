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
        DispatchQueue.concurrentPerform(iterations: 200) { (i) in
            sut.get(requestImageURL(color: i)) { downloadedImage, error in
                XCTAssertNotNil(downloadedImage, "Image \(i) is nil.")
                XCTAssertNil(error)
            }
        }
        
        XCTAssertNoThrow(try sut.deleteAll(), "Exception during deletion.")
    }
    
    func testRefresh() {
        
        testSaveImages()
        
        DispatchQueue.concurrentPerform(iterations: 200) { (i) in
            do {
                try sut.refresh(requestImageURL(color: i))
            } catch {
                XCTFail("An exception happened inside the dispatch queue.")
            }
        }
        
        XCTAssertNoThrow(try sut.refreshAll())
    }
    
    func testEditFail() {
        XCTAssertThrowsError(try sut.get(requestImageURL(color: 1), with: "inexistent_tag"),
                             "Did not throw an error with an inexistent tag.")
    }
    
//    func testEdit() {
//        let s = DispatchSemaphore(value: 0)
//        var image: UIImage?
//
//        sut.get(requestImageURL(color: 123), completion:  { downloadedImage, error in
//            defer { s.signal() }
//            XCTAssertNotNil(downloadedImage, "Exception while getting image.")
//            XCTAssertNil(error)
//            image = downloadedImage
//        })
//
//        s.wait()
//
//        XCTAssertNotNil(image,
//                        "Downloaded image is nil.")
//
//        XCTAssertNoThrow(try sut.edit(requestImageURL(color: 123), new: image!, saveWith: "edit1"),
//                         "Exception during edit.")
//
//        XCTAssertThrowsError(try sut.get(requestImageURL(color: 123), with: "edit2"),
//                             "No error while getting wrong edit tag.")
//
//        XCTAssertThrowsError(try sut.get(requestImageURL(color: 321), with: "edit1"),
//                             "No error while getting wrong image.")
//
//        XCTAssertNoThrow(try sut.get(requestImageURL(color: 123), with: "edit1"),
//                         "Error while retrieving tagged edit.")
//    }
        
    static var allTests = [
        ("testSharedExists", testSharedExists),
        ("testZeroFiles", testZeroFiles),
        ("testSaveImages", testSaveImages),
        ("testRefresh", testRefresh),
        ("testEditFail", testEditFail),
//        ("testEdit", testEdit)
    ]
    
}
