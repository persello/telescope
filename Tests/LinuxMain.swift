import XCTest

import TelescopeTests

var tests = [XCTestCaseEntry]()
//tests += TelescopeTests.allTests()
tests += CacheTests.allTests()
XCTMain(tests)
