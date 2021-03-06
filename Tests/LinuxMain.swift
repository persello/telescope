import XCTest

import TelescopeTests

var tests = [XCTestCaseEntry]()
tests += CacheTests.allTests()
XCTMain(tests)
