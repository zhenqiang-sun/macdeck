import XCTest
@testable import MacDeck

final class SoftwareUpdateServiceTests: XCTestCase {
    func testBuildUpgradeCommand() {
        let service = SoftwareUpdateService.shared

        let cask = SoftwarePackageItem(
            id: "brew:cask:docker",
            rawName: "docker",
            displayName: "Docker",
            currentVersion: "1.0",
            latestVersion: "2.0",
            source: .brewCask
        )
        XCTAssertEqual(service.buildUpgradeCommand(for: cask), "brew upgrade --cask docker")

        let formula = SoftwarePackageItem(
            id: "brew:formula:node",
            rawName: "node",
            displayName: "Node",
            currentVersion: "20.0",
            latestVersion: "22.0",
            source: .brewFormula
        )
        XCTAssertEqual(service.buildUpgradeCommand(for: formula), "brew upgrade node")

        let npm = SoftwarePackageItem(
            id: "npm:global:wrangler",
            rawName: "wrangler",
            displayName: "wrangler",
            currentVersion: "3.0",
            latestVersion: "4.0",
            source: .npmGlobal
        )
        XCTAssertEqual(service.buildUpgradeCommand(for: npm), "npm install -g wrangler@latest")

        let mas = SoftwarePackageItem(
            id: "mas:497799835",
            rawName: "497799835",
            displayName: "Xcode",
            currentVersion: "15.2",
            latestVersion: "15.3",
            source: .appStore
        )
        XCTAssertEqual(service.buildUpgradeCommand(for: mas), "mas upgrade 497799835")

        let volta = SoftwarePackageItem(
            id: "volta:@teable/cli",
            rawName: "@teable/cli",
            displayName: "@teable/cli",
            currentVersion: "0.6.29",
            latestVersion: "0.6.41",
            source: .volta
        )
        XCTAssertEqual(service.buildUpgradeCommand(for: volta), "volta install @teable/cli@latest")
    }

    func testBuildBatchUpgradeCommands() {
        let service = SoftwareUpdateService.shared

        let f1 = SoftwarePackageItem(id: "1", rawName: "node", displayName: "Node", currentVersion: "1", latestVersion: "2", source: .brewFormula)
        let f2 = SoftwarePackageItem(id: "2", rawName: "git", displayName: "Git", currentVersion: "1", latestVersion: "2", source: .brewFormula)
        let c1 = SoftwarePackageItem(id: "3", rawName: "docker", displayName: "Docker", currentVersion: "1", latestVersion: "2", source: .brewCask)
        let c2 = SoftwarePackageItem(id: "4", rawName: "chrome", displayName: "Chrome", currentVersion: "1", latestVersion: "2", source: .brewCask)
        let n1 = SoftwarePackageItem(id: "5", rawName: "wrangler", displayName: "Wrangler", currentVersion: "1", latestVersion: "2", source: .npmGlobal)
        let v1 = SoftwarePackageItem(id: "6", rawName: "teable", displayName: "Teable", currentVersion: "1", latestVersion: "2", source: .volta)

        let batches = service.buildBatchUpgradeCommands(for: [f1, f2, c1, c2, n1, v1])

        let formulaBatch = batches.first { $0.command == "brew upgrade node git" }
        XCTAssertNotNil(formulaBatch)
        XCTAssertEqual(formulaBatch?.items.count, 2)

        let caskBatch = batches.first { $0.command == "brew upgrade --cask docker chrome" }
        XCTAssertNotNil(caskBatch)
        XCTAssertEqual(caskBatch?.items.count, 2)

        let npmBatch = batches.first { $0.command == "npm install -g wrangler@latest" }
        XCTAssertNotNil(npmBatch)

        let voltaBatch = batches.first { $0.command == "volta install teable@latest" }
        XCTAssertNotNil(voltaBatch)
    }

    func testLogFileLocation() {
        let logURL = SoftwareUpdateService.shared.logFileURL
        XCTAssertTrue(logURL.path.contains("Library/Logs/MacDeck/software-update.log"))
    }

    func testAskpassScriptGenerationAndPermissions() {
        let askpassURL = SoftwareUpdateService.shared.askpassURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: askpassURL.path))
        XCTAssertTrue(askpassURL.path.contains("askpass.sh"))

        let attrs = try? FileManager.default.attributesOfItem(atPath: askpassURL.path)
        let perms = attrs?[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.intValue, 0o755)
    }

    func testBuildUninstallCommand() {
        let service = SoftwareUpdateService.shared

        let cask = SoftwarePackageItem(
            id: "brew:cask:docker-desktop",
            rawName: "docker-desktop",
            displayName: "Docker Desktop",
            currentVersion: "1.0",
            latestVersion: "1.0",
            source: .brewCask
        )
        XCTAssertEqual(service.buildUninstallCommand(for: cask), "brew uninstall --cask docker-desktop")

        let formula = SoftwarePackageItem(
            id: "brew:formula:node",
            rawName: "node",
            displayName: "Node",
            currentVersion: "20.0",
            latestVersion: "20.0",
            source: .brewFormula
        )
        XCTAssertEqual(service.buildUninstallCommand(for: formula), "brew uninstall node")

        let npm = SoftwarePackageItem(
            id: "npm:global:wrangler",
            rawName: "wrangler",
            displayName: "wrangler",
            currentVersion: "3.0",
            latestVersion: "3.0",
            source: .npmGlobal
        )
        XCTAssertEqual(service.buildUninstallCommand(for: npm), "npm uninstall -g wrangler")

        let volta = SoftwarePackageItem(
            id: "volta:@teable/cli",
            rawName: "@teable/cli",
            displayName: "@teable/cli",
            currentVersion: "0.6.29",
            latestVersion: "0.6.41",
            source: .volta
        )
        XCTAssertEqual(service.buildUninstallCommand(for: volta), "volta uninstall @teable/cli")
    }
}
