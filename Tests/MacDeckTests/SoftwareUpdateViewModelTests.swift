import XCTest
@testable import MacDeck

@MainActor
final class SoftwareUpdateViewModelTests: XCTestCase {
    func testFilteringBySourceAndSearch() {
        let vm = SoftwareUpdateViewModel()
        vm.items = [
            SoftwarePackageItem(id: "1", rawName: "google-chrome", displayName: "Google Chrome", currentVersion: "1", latestVersion: "2", source: .brewCask),
            SoftwarePackageItem(id: "2", rawName: "node", displayName: "Node.js", currentVersion: "20", latestVersion: "22", source: .brewFormula),
            SoftwarePackageItem(id: "3", rawName: "wrangler", displayName: "Wrangler", currentVersion: "3", latestVersion: "4", source: .npmGlobal)
        ]

        // All items
        XCTAssertEqual(vm.filteredItems.count, 3)

        // Filter by Cask
        vm.selectedFilter = .brewCask
        XCTAssertEqual(vm.filteredItems.count, 1)
        XCTAssertEqual(vm.filteredItems.first?.displayName, "Google Chrome")

        // Search query
        vm.selectedFilter = nil
        vm.searchQuery = "Node"
        XCTAssertEqual(vm.filteredItems.count, 1)
        XCTAssertEqual(vm.filteredItems.first?.displayName, "Node.js")
    }

    func testToggleSelectAll() {
        let vm = SoftwareUpdateViewModel()
        vm.items = [
            SoftwarePackageItem(id: "1", rawName: "a", displayName: "A", currentVersion: "1", latestVersion: "2", source: .brewFormula, isSelected: true),
            SoftwarePackageItem(id: "2", rawName: "b", displayName: "B", currentVersion: "1", latestVersion: "2", source: .brewFormula, isSelected: true)
        ]

        vm.toggleSelectAll()
        XCTAssertFalse(vm.items[0].isSelected)
        XCTAssertFalse(vm.items[1].isSelected)

        vm.toggleSelectAll()
        XCTAssertTrue(vm.items[0].isSelected)
        XCTAssertTrue(vm.items[1].isSelected)
    }

    func testMajorUpdateTriggersConfirmationAlertForSingleAndBatch() {
        let vm = SoftwareUpdateViewModel()
        let minorItem = SoftwarePackageItem(id: "1", rawName: "a", displayName: "A", currentVersion: "1.0.0", latestVersion: "1.0.1", source: .brewFormula, isSelected: true)
        let majorItem = SoftwarePackageItem(id: "2", rawName: "b", displayName: "B", currentVersion: "1.0.0", latestVersion: "2.0.0", source: .brewFormula, isSelected: true)

        vm.items = [minorItem, majorItem]

        // 1. Single major upgrade triggers alert
        vm.upgradeSingle(item: majorItem)
        XCTAssertTrue(vm.showMajorConfirmAlert)
        XCTAssertEqual(vm.majorUpdateItems.count, 1)
        XCTAssertEqual(vm.majorUpdateItems.first?.id, majorItem.id)
        XCTAssertFalse(vm.isUpgrading)

        // Reset
        vm.showMajorConfirmAlert = false
        vm.majorUpdateItems = []

        // 2. Batch upgrade with major item triggers alert
        vm.upgradeSelected()
        XCTAssertTrue(vm.showMajorConfirmAlert)
        XCTAssertEqual(vm.majorUpdateItems.count, 1)
        XCTAssertEqual(vm.majorUpdateItems.first?.id, majorItem.id)
        XCTAssertFalse(vm.isUpgrading)

        // 3. Confirming alert starts upgrade
        vm.confirmMajorUpgrade()
        XCTAssertFalse(vm.showMajorConfirmAlert)
        XCTAssertTrue(vm.isUpgrading)
    }

    func testNonMajorUpdateProceedsDirectlyWithoutAlert() {
        let vm = SoftwareUpdateViewModel()
        let minor1 = SoftwarePackageItem(id: "1", rawName: "a", displayName: "A", currentVersion: "1.0.0", latestVersion: "1.1.0", source: .brewFormula, isSelected: true)
        let minor2 = SoftwarePackageItem(id: "2", rawName: "b", displayName: "B", currentVersion: "1.2.0", latestVersion: "1.2.1", source: .brewFormula, isSelected: true)

        vm.items = [minor1, minor2]

        vm.upgradeSelected()
        XCTAssertFalse(vm.showMajorConfirmAlert)
        XCTAssertTrue(vm.isUpgrading)
    }
}
