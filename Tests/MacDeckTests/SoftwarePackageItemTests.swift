import XCTest
@testable import MacDeck

final class SoftwarePackageItemTests: XCTestCase {
    func testSoftwarePackageItemInitializationAndEquality() {
        let item = SoftwarePackageItem(
            id: "brew:cask:google-chrome",
            rawName: "google-chrome",
            displayName: "Google Chrome",
            currentVersion: "152.0.7977.83",
            latestVersion: "153.0.8010.37",
            source: .brewCask,
            isSelected: true,
            status: .available
        )

        XCTAssertEqual(item.id, "brew:cask:google-chrome")
        XCTAssertEqual(item.displayName, "Google Chrome")
        XCTAssertEqual(item.source, .brewCask)
        XCTAssertEqual(item.source.displayName, "桌面应用")
        XCTAssertEqual(item.isSelected, true)
        XCTAssertEqual(item.status, .available)
    }

    func testPackageSourceProperties() {
        XCTAssertEqual(PackageSource.brewCask.icon, "macwindow")
        XCTAssertEqual(PackageSource.brewFormula.icon, "terminal")
        XCTAssertEqual(PackageSource.npmGlobal.icon, "shippingbox")
        XCTAssertEqual(PackageSource.appStore.icon, "apple.logo")
        XCTAssertEqual(PackageSource.volta.icon, "bolt.fill")
        XCTAssertEqual(PackageSource.volta.displayName, "Volta")
    }
}
