import XCTest
@testable import MacDeck

final class MajorVersionDetectionTests: XCTestCase {
    func testStandardSemverMajorUpdate() {
        XCTAssertTrue(VersionHelper.isMajorUpdate(current: "1.2.3", latest: "2.0.0"))
        XCTAssertFalse(VersionHelper.isMajorUpdate(current: "1.2.3", latest: "1.3.0"))
        XCTAssertFalse(VersionHelper.isMajorUpdate(current: "1.2.3", latest: "1.2.4"))
    }

    func testVersionPrefixV() {
        XCTAssertTrue(VersionHelper.isMajorUpdate(current: "v20.0.0", latest: "v22.0.0"))
        XCTAssertFalse(VersionHelper.isMajorUpdate(current: "v20.1.0", latest: "v20.2.0"))
    }

    func testTwoComponentVersions() {
        XCTAssertTrue(VersionHelper.isMajorUpdate(current: "15.2", latest: "16.0"))
        XCTAssertFalse(VersionHelper.isMajorUpdate(current: "15.2", latest: "15.3"))
    }

    func testZeroMajorVersions() {
        XCTAssertFalse(VersionHelper.isMajorUpdate(current: "0.6.29", latest: "0.6.41"))
        XCTAssertTrue(VersionHelper.isMajorUpdate(current: "0.6.29", latest: "1.0.0"))
    }

    func testEdgeCases() {
        XCTAssertFalse(VersionHelper.isMajorUpdate(current: "", latest: "1.0.0"))
        XCTAssertFalse(VersionHelper.isMajorUpdate(current: "1.0.0", latest: "最新"))
        XCTAssertFalse(VersionHelper.isMajorUpdate(current: "abc", latest: "def"))
    }

    func testSoftwarePackageItemIsMajorUpdate() {
        let majorItem = SoftwarePackageItem(
            id: "node",
            rawName: "node",
            displayName: "Node.js",
            currentVersion: "20.1.0",
            latestVersion: "22.0.0",
            source: .brewFormula
        )
        XCTAssertTrue(majorItem.isMajorUpdate)

        let minorItem = SoftwarePackageItem(
            id: "teable",
            rawName: "@teable/cli",
            displayName: "@teable/cli",
            currentVersion: "0.6.29",
            latestVersion: "0.6.41",
            source: .volta
        )
        XCTAssertFalse(minorItem.isMajorUpdate)
    }
}
