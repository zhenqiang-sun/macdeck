import XCTest
@testable import MacDeck

final class MultiWindowSupportTests: XCTestCase {
    func testMultipleWindowsSameAppHaveUniqueIDs() {
        let win1 = WindowLayoutItem(
            bundleIdentifier: "com.apple.finder",
            appName: "Finder",
            profile: nil,
            windowIndex: 0,
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 800, height: 600)
        )

        let win2 = WindowLayoutItem(
            bundleIdentifier: "com.apple.finder",
            appName: "Finder",
            profile: nil,
            windowIndex: 1,
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 100, y: 100, width: 800, height: 600)
        )

        XCTAssertNotEqual(win1.id, win2.id)
        XCTAssertEqual(win1.id, "com.apple.finder:default:0")
        XCTAssertEqual(win2.id, "com.apple.finder:default:1")

        // 验证转换成字典时不会因重复 Key 崩溃
        let items = [win1, win2]
        let dict = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { (first: WindowLayoutItem, _) in first })
        XCTAssertEqual(dict.count, 2)
    }

    func testLegacyItemCompatibilityWithoutWindowIndex() throws {
        // 模拟旧版本 JSON（不包含 windowIndex 字段）
        let jsonString = """
        {
            "bundleIdentifier": "com.apple.finder",
            "appName": "Finder",
            "targetDisplayWidth": 1920,
            "targetDisplayHeight": 1080,
            "targetDisplayIsMain": true,
            "relativeFrame": {
                "x": 0,
                "y": 0,
                "width": 800,
                "height": 600
            },
            "isRecorded": true
        }
        """

        let data = jsonString.data(using: .utf8)!
        let item = try JSONDecoder().decode(WindowLayoutItem.self, from: data)

        XCTAssertEqual(item.windowIndex, 0)
        XCTAssertEqual(item.id, "com.apple.finder:default:0")
    }

    func testSmartTitleMatchingDoesNotCrossWireDifferentWindows() {
        // 模拟已记录的启动器窗口：Windows App（998x568，窗口化）
        let savedLauncher = WindowLayoutItem(
            bundleIdentifier: "com.microsoft.rdc.macos",
            appName: "Windows App",
            windowIndex: 0,
            windowTitle: "Windows App",
            targetDisplayAlias: "内屏",
            targetDisplayWidth: 2056,
            targetDisplayHeight: 1329,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 622, y: 109, width: 998, height: 568),
            isRecorded: true,
            isFullScreen: false
        )

        // 模拟当前活跃的远程桌面全屏会话：XHPC-LAN（1920x1080，全屏，倒挂屏）
        // 注意此时 XHPC-LAN 处在焦点，系统 discovery 给出 windowIndex = 0
        let liveSession = WindowLayoutItem(
            bundleIdentifier: "com.microsoft.rdc.macos",
            appName: "Windows App",
            windowIndex: 0,
            windowTitle: "XHPC-LAN",
            targetDisplayAlias: "倒挂",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 1052, y: -1080, width: 1920, height: 1080),
            isRecorded: false,
            isFullScreen: true
        )

        let savedItems = [savedLauncher]

        // 验证：即使两者 windowIndex 相同（均为 0），因为标题明确不同（XHPC-LAN vs Windows App），
        // 绝不能错误匹配导致全屏状态被覆盖为 false
        var matchedSaved: WindowLayoutItem? = nil
        if let snapTitle = liveSession.windowTitle, !snapTitle.isEmpty {
            matchedSaved = savedItems.first(where: {
                $0.bundleIdentifier == liveSession.bundleIdentifier &&
                $0.profile == liveSession.profile &&
                $0.windowTitle == snapTitle
            })
        }

        if matchedSaved == nil {
            if let match = savedItems.first(where: {
                $0.bundleIdentifier == liveSession.bundleIdentifier &&
                $0.profile == liveSession.profile &&
                $0.windowIndex == liveSession.windowIndex
            }) {
                if let snapTitle = liveSession.windowTitle, !snapTitle.isEmpty,
                   let savedTitle = match.windowTitle, !savedTitle.isEmpty,
                   snapTitle != savedTitle {
                    matchedSaved = nil
                } else {
                    matchedSaved = match
                }
            }
        }

        XCTAssertNil(matchedSaved, "XHPC-LAN 会话窗口不应错误匹配到启动器预设")
    }

    func testMinimizedWindowItemSerializationAndState() throws {
        let item = WindowLayoutItem(
            bundleIdentifier: "com.apple.Notes",
            appName: "Notes",
            windowIndex: 0,
            windowTitle: "Notes",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 800, height: 600),
            isRecorded: true,
            isFullScreen: false,
            isMinimized: true
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(WindowLayoutItem.self, from: data)

        XCTAssertEqual(decoded.isMinimized, true)
        XCTAssertEqual(decoded.isFullScreen, false)
    }
}


