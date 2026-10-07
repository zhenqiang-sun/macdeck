import XCTest
@testable import MacDeck

final class SystemInfoCacheStoreTests: XCTestCase {
    private var tempURL: URL!
    private var store: SystemInfoCacheStore!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("macdeck_cache_test_\(UUID().uuidString).json")
        store = SystemInfoCacheStore(customURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testLoadReturnsNilWhenNoCache() {
        XCTAssertNil(store.loadCachedReport())
    }

    func testSaveAndLoadCache() {
        let sampleReport = SystemInfoService.createDemoReport()
        store.saveCachedReport(sampleReport)

        let loaded = store.loadCachedReport()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.machineName, sampleReport.machineName)
        XCTAssertEqual(loaded?.chipName, sampleReport.chipName)
        XCTAssertEqual(loaded?.totalCores, sampleReport.totalCores)
        XCTAssertEqual(loaded?.modelIdentifier, sampleReport.modelIdentifier)
    }

    func testClearCache() {
        let sampleReport = SystemInfoService.createDemoReport()
        store.saveCachedReport(sampleReport)
        XCTAssertNotNil(store.loadCachedReport())

        store.clearCache()
        XCTAssertNil(store.loadCachedReport())
    }
}
