import XCTest
@testable import MacDeck

final class UpdateHistoryStoreTests: XCTestCase {
    var tempDirectory: URL!
    var storageURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        storageURL = tempDirectory.appendingPathComponent("update_history.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testAddAndLoadRecords() {
        let store = UpdateHistoryStore(storageURL: storageURL, maxCapacity: 3)
        XCTAssertTrue(store.loadRecords().isEmpty)

        let record1 = UpdateHistoryRecord(
            packageId: "pkg1",
            packageName: "pkg1",
            source: .brewFormula,
            previousVersion: "1.0",
            targetVersion: "1.1",
            status: .success,
            command: "brew upgrade pkg1",
            outputLog: "ok"
        )
        store.addRecord(record1)

        let loaded = store.loadRecords()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.packageId, "pkg1")
    }

    func testCapacityLimitFIFO() {
        let store = UpdateHistoryStore(storageURL: storageURL, maxCapacity: 2)

        for i in 1...3 {
            store.addRecord(UpdateHistoryRecord(
                packageId: "pkg\(i)",
                packageName: "pkg\(i)",
                source: .npmGlobal,
                previousVersion: "1.\(i)",
                targetVersion: "2.\(i)",
                status: .success,
                command: "npm",
                outputLog: ""
            ))
        }

        let loaded = store.loadRecords()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].packageId, "pkg3") // Most recent first
        XCTAssertEqual(loaded[1].packageId, "pkg2")
    }

    func testClearHistory() {
        let store = UpdateHistoryStore(storageURL: storageURL, maxCapacity: 5)
        store.addRecord(UpdateHistoryRecord(
            packageId: "pkg1",
            packageName: "pkg1",
            source: .brewFormula,
            previousVersion: "1.0",
            targetVersion: "1.1",
            status: .success,
            command: "brew upgrade pkg1",
            outputLog: "ok"
        ))
        XCTAssertEqual(store.loadRecords().count, 1)

        store.clearHistory()
        XCTAssertEqual(store.loadRecords().count, 0)
    }

    func testExportJSONAndCSV() {
        let store = UpdateHistoryStore(storageURL: storageURL)
        store.addRecord(UpdateHistoryRecord(
            packageId: "node",
            packageName: "node",
            source: .brewFormula,
            previousVersion: "18.0",
            targetVersion: "20.0",
            status: .success,
            command: "brew upgrade node",
            outputLog: "done",
            rollbackHint: "brew install node@18.0"
        ))

        let json = store.exportJSON()
        XCTAssertTrue(json.contains("node"))
        XCTAssertTrue(json.contains("20.0"))

        let csv = store.exportCSV()
        XCTAssertTrue(csv.contains("Timestamp,Package,Source,PreviousVersion,TargetVersion,Status,Command"))
        XCTAssertTrue(csv.contains("node,命令行,18.0,20.0,success"))
    }
}
