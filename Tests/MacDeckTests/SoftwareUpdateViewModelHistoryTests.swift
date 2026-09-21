import XCTest
@testable import MacDeck

@MainActor
final class SoftwareUpdateViewModelHistoryTests: XCTestCase {
    var tempDirectory: URL!
    var storageURL: URL!
    var store: UpdateHistoryStore!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        storageURL = tempDirectory.appendingPathComponent("history.json")
        store = UpdateHistoryStore(storageURL: storageURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testHistoryFiltering() {
        let vm = SoftwareUpdateViewModel(historyStore: store)

        store.addRecord(UpdateHistoryRecord(
            packageId: "git",
            packageName: "git",
            source: .brewFormula,
            previousVersion: "2.40",
            targetVersion: "2.41",
            status: .success,
            command: "brew upgrade git",
            outputLog: "ok"
        ))
        store.addRecord(UpdateHistoryRecord(
            packageId: "node",
            packageName: "node",
            source: .brewFormula,
            previousVersion: "18.0",
            targetVersion: "20.0",
            status: .failed,
            command: "brew upgrade node",
            outputLog: "error"
        ))

        vm.loadHistory()
        XCTAssertEqual(vm.historyRecords.count, 2)
        XCTAssertEqual(vm.filteredHistoryRecords.count, 2)

        // Filter by search
        vm.historySearchQuery = "git"
        XCTAssertEqual(vm.filteredHistoryRecords.count, 1)
        XCTAssertEqual(vm.filteredHistoryRecords.first?.packageName, "git")

        // Filter by status
        vm.historySearchQuery = ""
        vm.historyStatusFilter = .failed
        XCTAssertEqual(vm.filteredHistoryRecords.count, 1)
        XCTAssertEqual(vm.filteredHistoryRecords.first?.packageName, "node")
    }

    func testClearHistory() {
        let vm = SoftwareUpdateViewModel(historyStore: store)
        store.addRecord(UpdateHistoryRecord(
            packageId: "ripgrep",
            packageName: "ripgrep",
            source: .cargo,
            previousVersion: "13.0",
            targetVersion: "14.0",
            status: .success,
            command: "cargo",
            outputLog: ""
        ))
        vm.loadHistory()
        XCTAssertEqual(vm.historyRecords.count, 1)

        vm.clearHistory()
        XCTAssertEqual(vm.historyRecords.count, 0)
        XCTAssertTrue(store.loadRecords().isEmpty)
    }
}
