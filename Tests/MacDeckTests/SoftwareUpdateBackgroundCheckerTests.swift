import XCTest
@testable import MacDeck

@MainActor
final class SoftwareUpdateBackgroundCheckerTests: XCTestCase {
    func testCheckerInitialStateAndManualUpdate() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = UpdateSettingsStore(fileURL: tempURL)
        let checker = SoftwareUpdateBackgroundChecker(store: store)

        XCTAssertEqual(checker.pendingUpdateCount, 0)
        XCTAssertTrue(checker.pendingUpdateItems.isEmpty)
        XCTAssertFalse(checker.isChecking)

        // Manual update
        let item = SoftwarePackageItem(
            id: "brew:formula:node",
            rawName: "node",
            displayName: "node",
            currentVersion: "20.0",
            latestVersion: "22.0",
            source: .brewFormula
        )
        checker.updatePendingCount(1, items: [item])
        XCTAssertEqual(checker.pendingUpdateCount, 1)
        XCTAssertEqual(checker.pendingUpdateItems.count, 1)
        XCTAssertEqual(checker.pendingUpdateItems.first?.rawName, "node")
    }

    func testCheckRespectsStoreInterval() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = UpdateSettingsStore(fileURL: tempURL)
        _ = SoftwareUpdateBackgroundChecker(store: store)

        // Disable auto check
        store.setAutoCheckEnabled(false)
        XCTAssertFalse(store.shouldPerformAutoCheck())

        // Enable auto check
        store.setAutoCheckEnabled(true)
        XCTAssertTrue(store.shouldPerformAutoCheck())

        // After recordCheck, should not perform check immediately
        store.recordCheck()
        XCTAssertFalse(store.shouldPerformAutoCheck())
    }
}
