import XCTest
@testable import MacDeck

@MainActor
final class EnvironmentMaintenanceViewModelTests: XCTestCase {
    func testInitialStateAndCalculations() {
        let vm = EnvironmentMaintenanceViewModel()
        XCTAssertFalse(vm.isDiagnosing)
        XCTAssertFalse(vm.isCleaning)
        XCTAssertFalse(vm.showCleanConfirmationAlert)
        XCTAssertEqual(vm.totalCleanableBytes, 0)
        XCTAssertEqual(vm.overallHealth, .healthy)

        vm.doctorItems = [
            DoctorItem(id: "1", title: "A", subtitle: "", status: .healthy, summary: ""),
            DoctorItem(id: "2", title: "B", subtitle: "", status: .warning, summary: "")
        ]
        XCTAssertEqual(vm.overallHealth, .warning)

        vm.doctorItems.append(DoctorItem(id: "3", title: "C", subtitle: "", status: .error, summary: ""))
        XCTAssertEqual(vm.overallHealth, .error)

        vm.cleanupItems = [
            CleanupItem(id: "1", name: "A", pathDescription: "", sizeBytes: 1000),
            CleanupItem(id: "2", name: "B", pathDescription: "", sizeBytes: 2500)
        ]
        XCTAssertEqual(vm.totalCleanableBytes, 3500)
    }

    func testRequestCleanTriggersConfirmation() {
        let vm = EnvironmentMaintenanceViewModel()
        let item = CleanupItem(id: "brew", name: "Brew", pathDescription: "", sizeBytes: 500)
        vm.requestClean(target: .single(item))

        XCTAssertTrue(vm.showCleanConfirmationAlert)
        XCTAssertEqual(vm.pendingCleanTarget, .single(item))
    }

    func testAppendConsole() {
        let vm = EnvironmentMaintenanceViewModel()
        vm.appendConsole("line 1")
        vm.appendConsole("line 2\n")
        XCTAssertTrue(vm.consoleLog.contains("line 1\n"))
        XCTAssertTrue(vm.consoleLog.contains("line 2\n"))
    }
}
