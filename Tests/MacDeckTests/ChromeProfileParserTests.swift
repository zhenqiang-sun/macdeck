import XCTest
@testable import MacDeck

final class ChromeProfileParserTests: XCTestCase {
    func testParseStandardChromeMultiProfile() {
        let title = "GitHub - apple/swift: The Swift Programming Language - Google Chrome - Work"
        let result = ChromeProfileParser.parse(windowTitle: title)
        XCTAssertEqual(result.profile, "Work")
        XCTAssertEqual(result.pageTitle, "GitHub - apple/swift: The Swift Programming Language")
    }

    func testParsePersonalProfile() {
        let title = "Hacker News - Google Chrome - Personal"
        let result = ChromeProfileParser.parse(windowTitle: title)
        XCTAssertEqual(result.profile, "Personal")
        XCTAssertEqual(result.pageTitle, "Hacker News")
    }

    func testParseSingleProfileWithoutProfileSuffix() {
        let title = "GitHub - Google Chrome"
        let result = ChromeProfileParser.parse(windowTitle: title)
        XCTAssertNil(result.profile)
        XCTAssertEqual(result.pageTitle, "GitHub")
    }

    func testNonChromeApp() {
        let title = "Visual Studio Code - main.swift"
        let result = ChromeProfileParser.parse(windowTitle: title)
        XCTAssertNil(result.profile)
        XCTAssertEqual(result.pageTitle, title)
    }
}
