import XCTest
@testable import MacDeck

final class EnvironmentDoctorServiceTests: XCTestCase {
    func testParseBrewDoctorOutputHealthy() {
        let output = """
        Please note that these warnings are just used to help the Homebrew maintainers
        Your system is ready to brew.
        """
        let (status, summary, details, fix) = EnvironmentDoctorService.parseBrewDoctor(output: output)
        XCTAssertEqual(status, .healthy)
        XCTAssertTrue(summary.contains("正常") || summary.contains("ready"))
        XCTAssertTrue(details.isEmpty)
        XCTAssertNil(fix)
    }

    func testParseBrewDoctorOutputWarning() {
        let output = """
        Warning: Some installed formulae are deprecated or disabled.
        You should find replacements for the following formulae:
          node@20

        Warning: The following taps are not trusted:
          some/tap
        """
        let (status, summary, details, fix) = EnvironmentDoctorService.parseBrewDoctor(output: output)
        XCTAssertEqual(status, .warning)
        XCTAssertTrue(summary.contains("警告"))
        XCTAssertEqual(details.count, 2)
        XCTAssertNotNil(fix)
    }

    func testParseBrewDoctorOutputError() {
        let output = """
        Error: Broken symlinks were found in /opt/homebrew:
          /opt/homebrew/bin/bad_link
        """
        let (status, summary, details, _) = EnvironmentDoctorService.parseBrewDoctor(output: output)
        XCTAssertEqual(status, .error)
        XCTAssertTrue(summary.contains("异常") || summary.contains("错误"))
        XCTAssertFalse(details.isEmpty)
    }

    func testBuildCleanCommands() {
        let service = EnvironmentDoctorService.shared

        let brewItem = CleanupItem(id: "brew", name: "Homebrew", pathDescription: "")
        XCTAssertEqual(service.buildCleanCommand(for: brewItem), "HOMEBREW_NO_AUTO_UPDATE=1 brew cleanup -s --prune=all")

        let npmItem = CleanupItem(id: "npm", name: "npm", pathDescription: "")
        XCTAssertEqual(service.buildCleanCommand(for: npmItem), "npm cache clean --force")

        let pipItem = CleanupItem(id: "pip", name: "pip", pathDescription: "")
        XCTAssertEqual(service.buildCleanCommand(for: pipItem), "pip3 cache purge")

        let cargoItem = CleanupItem(id: "cargo", name: "Cargo", pathDescription: "")
        XCTAssertTrue(service.buildCleanCommand(for: cargoItem).contains(".cargo/registry/cache"))
    }
}
