import XCTest
@testable import MacDeck

final class EnvironmentDoctorModelTests: XCTestCase {
    func testHealthStatusIconsAndEquality() {
        let healthy = HealthStatus.healthy
        XCTAssertEqual(healthy.iconName, "checkmark.circle.fill")
        XCTAssertEqual(HealthStatus.warning.iconName, "exclamationmark.triangle.fill")
        XCTAssertEqual(HealthStatus.error.iconName, "xmark.circle.fill")
        XCTAssertEqual(HealthStatus.notInstalled.iconName, "minus.circle.fill")
    }

    func testDoctorItemInitialization() {
        let item = DoctorItem(
            id: "brew",
            title: "Homebrew",
            subtitle: "/opt/homebrew",
            status: .healthy,
            summary: "环境正常",
            details: ["无严重异常"],
            fixCommand: "brew update"
        )
        XCTAssertEqual(item.id, "brew")
        XCTAssertEqual(item.title, "Homebrew")
        XCTAssertEqual(item.status, .healthy)
        XCTAssertEqual(item.fixCommand, "brew update")
        XCTAssertEqual(item.details.count, 1)
    }

    func testCleanupItemFormattedSize() {
        var item = CleanupItem(
            id: "npm",
            name: "npm 缓存",
            pathDescription: "~/.npm",
            sizeBytes: 1024 * 1024 * 50 // 50MB
        )
        XCTAssertTrue(item.formattedSize.contains("50") || item.formattedSize.contains("MB"))

        item.isScanning = true
        XCTAssertEqual(item.formattedSize, "正在计算...")

        item.isScanning = false
        item.sizeBytes = 0
        XCTAssertEqual(item.formattedSize, "0 B (无缓存)")
    }
}
