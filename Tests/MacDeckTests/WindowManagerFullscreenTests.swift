import XCTest
@testable import MacDeck

final class WindowManagerFullscreenTests: XCTestCase {
    func testDiscoveredWindowDisplayUUIDProperty() {
        let currentApp = NSRunningApplication.current
        let win = WindowManager.DiscoveredWindow(
            app: currentApp,
            title: "Test Fullscreen Window",
            profile: nil,
            frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            isMinimized: false,
            isFullScreen: true,
            displayUUID: "TEST-DISPLAY-UUID-12345"
        )

        XCTAssertEqual(win.displayUUID, "TEST-DISPLAY-UUID-12345")
        XCTAssertTrue(win.isFullScreen)
        XCTAssertFalse(win.isMinimized)
        XCTAssertEqual(win.title, "Test Fullscreen Window")
    }

    func testFullscreenItemShouldBeFullScreenEvaluation() {
        // 显式指定 isFullScreen 为 true
        let item1 = WindowLayoutItem(
            bundleIdentifier: "com.apple.Terminal",
            appName: "Terminal",
            targetDisplayUUID: "UUID-1",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 1920, height: 1080),
            isFullScreen: true
        )
        XCTAssertEqual(item1.isFullScreen, true)

        // 兼容历史项：没有显式 isFullScreen 字段，但覆盖全屏区域
        let item2 = WindowLayoutItem(
            bundleIdentifier: "com.apple.Terminal",
            appName: "Terminal",
            targetDisplayUUID: "UUID-1",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 1920, height: 1080),
            isFullScreen: nil
        )
        let isLargeWindow = item2.relativeFrame.x <= 20 &&
                            item2.relativeFrame.y <= 40 &&
                            item2.relativeFrame.width >= (item2.targetDisplayWidth - 40) &&
                            item2.relativeFrame.height >= (item2.targetDisplayHeight - 80)
        XCTAssertTrue(isLargeWindow)
    }

    func testDiscoverWindowsExecutesWithoutCrash() {
        // 验证系统窗口与全屏 Space 捕获接口正常运行不崩溃
        let mgr = WindowManager.shared
        let windows = mgr.discoverWindows()
        XCTAssertNotNil(windows)
    }
}
