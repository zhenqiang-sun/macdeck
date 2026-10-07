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

    func testMajorUpdateCancelResetsAlertAndState() {
        let vm = SoftwareUpdateViewModel()
        let majorItem = SoftwarePackageItem(id: "2", rawName: "b", displayName: "B", currentVersion: "1.0.0", latestVersion: "2.0.0", source: .brewFormula, isSelected: true)
        vm.items = [majorItem]

        vm.upgradeSelected()
        XCTAssertTrue(vm.showMajorConfirmAlert)
        XCTAssertEqual(vm.majorUpdateItems.count, 1)

        vm.cancelMajorUpgrade()
        XCTAssertFalse(vm.showMajorConfirmAlert)
        XCTAssertTrue(vm.majorUpdateItems.isEmpty)
        XCTAssertFalse(vm.isUpgrading)
    }

    func testIgnoreAndUnignoreVersionUpdatesItemStateAndSelection() {
        let vm = SoftwareUpdateViewModel()
        let item = SoftwarePackageItem(id: "pkg-1", rawName: "corepack-test", displayName: "Corepack", currentVersion: "0.20.0", latestVersion: "0.36.0", source: .npmGlobal, isSelected: true)
        vm.items = [item]

        // 1. Ignore version
        vm.ignoreVersion(for: item)
        XCTAssertTrue(vm.items[0].isIgnored)
        XCTAssertFalse(vm.items[0].isSelected, "Ignored item must be automatically deselected")
        XCTAssertTrue(vm.statusMessage.contains("已忽略"))

        // 2. Unignore version
        vm.unignoreVersion(for: item)
        XCTAssertFalse(vm.items[0].isIgnored)
        XCTAssertTrue(vm.items[0].isSelected, "Unignored item must be reselected")
        XCTAssertTrue(vm.statusMessage.contains("已恢复"))

        // Cleanup
        UpdateSettingsStore.shared.unignore(rawName: "corepack-test")
    }

    func testPinAndUnpinPackageUpdatesItemStateAndSelection() {
        let vm = SoftwareUpdateViewModel()
        let item = SoftwarePackageItem(id: "pkg-2", rawName: "node-test", displayName: "Node", currentVersion: "20.0.0", latestVersion: "22.0.0", source: .brewFormula, isSelected: true)
        vm.items = [item]

        // 1. Pin package
        vm.pinPackage(for: item)
        XCTAssertTrue(vm.items[0].isPinned)
        XCTAssertFalse(vm.items[0].isSelected, "Pinned item must be deselected")

        // 2. Unpin package
        vm.unpinPackage(for: item)
        XCTAssertFalse(vm.items[0].isPinned)
        XCTAssertTrue(vm.items[0].isSelected)

        // Cleanup
        UpdateSettingsStore.shared.unpin(rawName: "node-test")
    }

    func testToggleSelectAllExcludesPinnedAndIgnoredPackages() {
        let vm = SoftwareUpdateViewModel()
        let normalItem = SoftwarePackageItem(id: "1", rawName: "app-normal", displayName: "Normal", currentVersion: "1.0", latestVersion: "1.1", source: .brewFormula, isSelected: false)
        var ignoredItem = SoftwarePackageItem(id: "2", rawName: "app-ignored", displayName: "Ignored", currentVersion: "1.0", latestVersion: "1.1", source: .brewFormula, isSelected: false)
        ignoredItem.isIgnored = true

        vm.items = [normalItem, ignoredItem]

        // Select all should only select the normal item
        vm.toggleSelectAll()
        XCTAssertTrue(vm.items[0].isSelected)
        XCTAssertFalse(vm.items[1].isSelected, "Ignored item must not be selected by toggleSelectAll")
    }

    func testRemoveItemFromUpdatesList() {
        let vm = SoftwareUpdateViewModel()
        let item1 = SoftwarePackageItem(id: "1", rawName: "pkg-1", displayName: "Pkg 1", currentVersion: "1", latestVersion: "2", source: .brewFormula)
        let item2 = SoftwarePackageItem(id: "2", rawName: "pkg-2", displayName: "Pkg 2", currentVersion: "1", latestVersion: "2", source: .brewFormula)
        vm.items = [item1, item2]

        vm.removeItemFromUpdatesList(for: item1)
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.id, "2")
    }
}
