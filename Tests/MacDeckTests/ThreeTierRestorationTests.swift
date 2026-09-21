import XCTest
@testable import MacDeck

final class ThreeTierRestorationTests: XCTestCase {
    func testTier1UUIDMatching() {
        let screens = NSScreen.screens
        guard let currentScreen = screens.first else { return }
        let currentScreenNumber = currentScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
        let currentUUID = DisplayManager.getDisplayUUID(for: currentScreenNumber)

        let item = WindowLayoutItem(
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari",
            targetDisplayUUID: currentUUID,
            targetDisplayAlias: "主工作屏",
            targetDisplayWidth: currentScreen.frame.width,
            targetDisplayHeight: currentScreen.frame.height,
            targetDisplayIsMain: currentScreen == NSScreen.main,
            relativeFrame: RelativeRect(x: 50, y: 50, width: 600, height: 400)
        )

        let (resolvedFrame, resolvedScreen) = DisplayManager.shared.resolveAbsoluteFrame(
            relative: item.relativeFrame,
            targetUUID: item.targetDisplayUUID,
            targetAlias: item.targetDisplayAlias,
            targetWidth: item.targetDisplayWidth,
            targetHeight: item.targetDisplayHeight,
            targetIsMain: item.targetDisplayIsMain
        )

        XCTAssertEqual(resolvedScreen, currentScreen)
        XCTAssertGreaterThanOrEqual(resolvedFrame.origin.x, currentScreen.frame.origin.x)
        XCTAssertGreaterThanOrEqual(resolvedFrame.origin.y, currentScreen.frame.origin.y)
    }

    func testTier2AliasMatching() {
        let screens = NSScreen.screens
        guard let currentScreen = screens.first else { return }
        let currentScreenNumber = currentScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
        let currentUUID = DisplayManager.getDisplayUUID(for: currentScreenNumber)

        let testAlias = "自定义别名测试屏"
        let aliases = [currentUUID: testAlias]

        let item = WindowLayoutItem(
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari",
            targetDisplayUUID: "UNKNOWN-NONEXISTENT-UUID",
            targetDisplayAlias: testAlias,
            targetDisplayWidth: 9999,
            targetDisplayHeight: 9999,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 20, y: 20, width: 500, height: 300)
        )

        let (_, resolvedScreen) = DisplayManager.shared.resolveAbsoluteFrame(
            relative: item.relativeFrame,
            targetUUID: item.targetDisplayUUID,
            targetAlias: item.targetDisplayAlias,
            targetWidth: item.targetDisplayWidth,
            targetHeight: item.targetDisplayHeight,
            targetIsMain: item.targetDisplayIsMain,
            displayAliases: aliases
        )

        XCTAssertEqual(resolvedScreen, currentScreen, "Should resolve by alias even if UUID does not match")
    }

    func testTier3Fallback() {
        let item = WindowLayoutItem(
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari",
            targetDisplayUUID: "UNKNOWN-UUID",
            targetDisplayAlias: "UNKNOWN-ALIAS",
            targetDisplayWidth: 1234,
            targetDisplayHeight: 5678,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 10, y: 10, width: 400, height: 300)
        )

        let (_, resolvedScreen) = DisplayManager.shared.resolveAbsoluteFrame(
            relative: item.relativeFrame,
            targetUUID: item.targetDisplayUUID,
            targetAlias: item.targetDisplayAlias,
            targetWidth: item.targetDisplayWidth,
            targetHeight: item.targetDisplayHeight,
            targetIsMain: item.targetDisplayIsMain,
            displayAliases: [:]
        )

        XCTAssertEqual(resolvedScreen, NSScreen.main, "Should fall back to main screen if targetDisplayIsMain is true")
    }
}
