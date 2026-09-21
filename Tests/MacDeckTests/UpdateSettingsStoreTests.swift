import XCTest
@testable import MacDeck

final class UpdateSettingsStoreTests: XCTestCase {
    var tempDirectory: URL!
    var store: UpdateSettingsStore!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let testConfigURL = tempDirectory.appendingPathComponent("update_settings.json")
        store = UpdateSettingsStore(fileURL: testConfigURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testInitialStateIsEmpty() {
        XCTAssertFalse(store.shouldSkipUpdate(rawName: "node", latestVersion: "22.0.0"))
        XCTAssertFalse(store.isPinned(rawName: "node"))
        XCTAssertNil(store.ignoredVersion(for: "node"))
    }

    func testIgnoreSpecificVersion() {
        store.ignoreVersion(rawName: "node", version: "22.0.0")
        XCTAssertTrue(store.shouldSkipUpdate(rawName: "node", latestVersion: "22.0.0"))
        // A newer version should NOT be skipped
        XCTAssertFalse(store.shouldSkipUpdate(rawName: "node", latestVersion: "22.1.0"))

        // Unignore
        store.unignore(rawName: "node")
        XCTAssertFalse(store.shouldSkipUpdate(rawName: "node", latestVersion: "22.0.0"))
    }

    func testPinPackage() {
        store.pinPackage(rawName: "docker")
        XCTAssertTrue(store.isPinned(rawName: "docker"))
        XCTAssertTrue(store.shouldSkipUpdate(rawName: "docker", latestVersion: "5.0.0"))
        XCTAssertTrue(store.shouldSkipUpdate(rawName: "docker", latestVersion: "6.0.0"))

        // Unpin
        store.unpin(rawName: "docker")
        XCTAssertFalse(store.isPinned(rawName: "docker"))
        XCTAssertFalse(store.shouldSkipUpdate(rawName: "docker", latestVersion: "5.0.0"))
    }

    func testPersistenceAcrossInstances() {
        let testConfigURL = tempDirectory.appendingPathComponent("update_settings.json")
        store.ignoreVersion(rawName: "@teable/cli", version: "0.6.41")
        store.pinPackage(rawName: "node")

        let newStore = UpdateSettingsStore(fileURL: testConfigURL)
        XCTAssertTrue(newStore.shouldSkipUpdate(rawName: "@teable/cli", latestVersion: "0.6.41"))
        XCTAssertFalse(newStore.shouldSkipUpdate(rawName: "@teable/cli", latestVersion: "0.6.42"))
        XCTAssertTrue(newStore.isPinned(rawName: "node"))
    }

    func testAutoCheckSettingsAndInterval() {
        // 默认开启，间隔24小时
        XCTAssertTrue(store.autoCheckEnabled)
        XCTAssertEqual(store.checkIntervalHours, 24)
        XCTAssertNil(store.lastCheckTimestamp)
        XCTAssertTrue(store.shouldPerformAutoCheck(now: Date()))

        // 记录检查后，短时间内不应重复检查
        let now = Date()
        store.recordCheck(at: now)
        XCTAssertFalse(store.shouldPerformAutoCheck(now: now.addingTimeInterval(3600))) // 1小时后不应检查
        XCTAssertTrue(store.shouldPerformAutoCheck(now: now.addingTimeInterval(25 * 3600))) // 25小时后应该检查

        // 关闭自动检查
        store.setAutoCheckEnabled(false)
        XCTAssertFalse(store.autoCheckEnabled)
        XCTAssertFalse(store.shouldPerformAutoCheck(now: now.addingTimeInterval(30 * 3600)))

        // 更改间隔
        store.setAutoCheckEnabled(true)
        store.setCheckIntervalHours(12)
        XCTAssertEqual(store.checkIntervalHours, 12)
        XCTAssertTrue(store.shouldPerformAutoCheck(now: now.addingTimeInterval(13 * 3600)))
    }
}
