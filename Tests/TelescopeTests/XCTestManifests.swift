import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
//        testCase(TelescopeTests.allTests),
        testCase(CacheTests.allTests)
    ]
}
#endif
