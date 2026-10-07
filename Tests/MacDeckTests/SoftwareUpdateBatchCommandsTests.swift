import XCTest
@testable import MacDeck

final class SoftwareUpdateBatchCommandsTests: XCTestCase {
    private var service: SoftwareUpdateService!

    override func setUp() {
        super.setUp()
        service = SoftwareUpdateService()
    }

    func testBrewCommandsContainNoAutoUpdateFlags() {
        let formula = SoftwarePackageItem(id: "1", rawName: "cairo", displayName: "cairo", currentVersion: "1.0", latestVersion: "1.1", source: .brewFormula)
        let cask = SoftwarePackageItem(id: "2", rawName: "google-chrome", displayName: "Google Chrome", currentVersion: "153", latestVersion: "155", source: .brewCask)

        let formulaCmd = service.buildUpgradeCommand(for: formula)
        XCTAssertTrue(formulaCmd.contains("HOMEBREW_NO_AUTO_UPDATE=1"))
        XCTAssertTrue(formulaCmd.contains("HOMEBREW_NO_ENV_HINTS=1"))
        XCTAssertTrue(formulaCmd.contains("brew upgrade cairo"))

        let caskCmd = service.buildUpgradeCommand(for: cask)
        XCTAssertTrue(caskCmd.contains("HOMEBREW_NO_AUTO_UPDATE=1"))
        XCTAssertTrue(caskCmd.contains("HOMEBREW_NO_ENV_HINTS=1"))
        XCTAssertTrue(caskCmd.contains("brew upgrade --cask google-chrome"))
    }

    func testBatchCommandsSplitsCasksIndividuallyAndGroupsFormulae() {
        let formula1 = SoftwarePackageItem(id: "1", rawName: "cmake", displayName: "cmake", currentVersion: "1.0", latestVersion: "1.1", source: .brewFormula)
        let formula2 = SoftwarePackageItem(id: "2", rawName: "docker", displayName: "docker", currentVersion: "20.0", latestVersion: "20.1", source: .brewFormula)
        let cask1 = SoftwarePackageItem(id: "3", rawName: "docker-desktop", displayName: "Docker Desktop", currentVersion: "4.90", latestVersion: "4.94", source: .brewCask)
        let cask2 = SoftwarePackageItem(id: "4", rawName: "google-chrome", displayName: "Google Chrome", currentVersion: "153", latestVersion: "155", source: .brewCask)
        let npmItem = SoftwarePackageItem(id: "5", rawName: "vercel", displayName: "vercel", currentVersion: "30.0", latestVersion: "31.0", source: .npmGlobal)

        let batches = service.buildBatchUpgradeCommands(for: [formula1, formula2, cask1, cask2, npmItem])

        // Should have:
        // 1 batch for combined formulae (cmake + docker)
        // 2 separate batches for each cask (docker-desktop, google-chrome)
        // 1 batch for npmItem (vercel)
        // Total = 4 batches
        XCTAssertEqual(batches.count, 4)

        // Verify formulae batch
        let formulaBatch = batches.first(where: { $0.items.allSatisfy { $0.source == .brewFormula } })
        XCTAssertNotNil(formulaBatch)
        XCTAssertEqual(formulaBatch?.items.count, 2)
        XCTAssertTrue(formulaBatch?.command.contains("brew upgrade cmake docker") == true)
        XCTAssertTrue(formulaBatch?.command.contains("HOMEBREW_NO_AUTO_UPDATE=1") == true)

        // Verify cask batches are separated per item
        let caskBatches = batches.filter { $0.items.allSatisfy { $0.source == .brewCask } }
        XCTAssertEqual(caskBatches.count, 2)
        for cb in caskBatches {
            XCTAssertEqual(cb.items.count, 1)
            XCTAssertTrue(cb.command.contains("brew upgrade --cask"))
            XCTAssertTrue(cb.command.contains("HOMEBREW_NO_AUTO_UPDATE=1"))
        }

        // Verify npm batch
        let npmBatch = batches.first(where: { $0.items.allSatisfy { $0.source == .npmGlobal } })
        XCTAssertNotNil(npmBatch)
        XCTAssertEqual(npmBatch?.items.count, 1)
    }

    func testFailureDiagnosticsDetection() {
        let missingAppLog = "Error: lbjlaq/antigravity-manager/antigravity-tools: It seems the App source '/Applications/Antigravity Tools.app' is not there."
        let reason1 = SoftwareUpdateService.diagnoseFailureReason(from: missingAppLog)
        XCTAssertTrue(reason1.contains("原应用可能已被手动删除") || reason1.contains("建议重新安装"))

        let conflictLog = "Volta error: Executable 'pnpm' is already installed by pnpm"
        let reason2 = SoftwareUpdateService.diagnoseFailureReason(from: conflictLog)
        XCTAssertTrue(reason2.contains("冲突"))

        let permLog = "Permission denied @ apply2files - /usr/local/share"
        let reason3 = SoftwareUpdateService.diagnoseFailureReason(from: permLog)
        XCTAssertTrue(reason3.contains("权限"))
    }
}
