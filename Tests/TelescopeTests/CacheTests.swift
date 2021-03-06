//
//  CacheTests.swift
//  TelescopeTests
//
//  Created by Riccardo Persello on 06/03/21.
//

import XCTest
@testable import Telescope

class CacheTests: XCTestCase {
    
    var sut: Cache!
    
    override func setUpWithError() throws {
        sut = try TelescopeImageCache()
    }

    override func tearDownWithError() throws {
        sut = nil
    }

    func testZeroFiles() {
        XCTAssert(sut., <#T##message: String##String#>)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
