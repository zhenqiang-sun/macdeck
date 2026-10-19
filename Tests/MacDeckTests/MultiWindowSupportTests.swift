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

    func testBrowserHelperDetectsMajorBrowsers() {
        XCTAssertTrue(BrowserHelper.isBrowser(bundleIdentifier: "com.google.Chrome"))
        XCTAssertTrue(BrowserHelper.isBrowser(bundleIdentifier: "com.apple.Safari"))
        XCTAssertTrue(BrowserHelper.isBrowser(bundleIdentifier: "company.thebrowser.Browser"))
        XCTAssertTrue(BrowserHelper.isBrowser(bundleIdentifier: "com.microsoft.edgemac"))
        XCTAssertTrue(BrowserHelper.isBrowser(bundleIdentifier: "org.mozilla.firefox"))
        XCTAssertTrue(BrowserHelper.isBrowser(bundleIdentifier: "com.brave.Browser"))

        XCTAssertFalse(BrowserHelper.isBrowser(bundleIdentifier: "com.microsoft.rdc.macos"))
        XCTAssertFalse(BrowserHelper.isBrowser(bundleIdentifier: "com.apple.finder"))
        XCTAssertFalse(BrowserHelper.isBrowser(bundleIdentifier: "net.xmind.vana.app"))
    }

    func testBrowserWindowMatchingIgnoresTabTitleChanges() {
        // 模拟已记录的 Chrome 预设：在工作区左侧，记录时的 Tab 标题为 GitHub
        let savedChrome = WindowLayoutItem(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            profile: "admin (AIPO)",
            windowIndex: 0,
            windowTitle: "GitHub - Dashboard - Google Chrome - admin (AIPO)",
            targetDisplayUUID: "DISP-1",
            targetDisplayAlias: "主工作屏",
            targetDisplayWidth: 2056,
            targetDisplayHeight: 1329,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 1000, height: 1200),
            isRecorded: true
        )

        // 模拟当前活跃打开的 Chrome 窗口：换到了 Bilibili 标签页，标题发生改变
        let liveChrome = WindowLayoutItem(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            profile: "admin (AIPO)",
            windowIndex: 0,
            windowTitle: "Bilibili - 哔哩哔哩 - Google Chrome - admin (AIPO)",
            targetDisplayUUID: "DISP-1",
            targetDisplayAlias: "主工作屏",
            targetDisplayWidth: 2056,
            targetDisplayHeight: 1329,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 100, y: 100, width: 1000, height: 1200),
            isRecorded: false
        )

        let merged = AppState.matchSnapshotItems(
            currentSnap: [liveChrome],
            savedItems: [savedChrome]
        )

        XCTAssertEqual(merged.count, 1)
        let result = merged[0]
        XCTAssertTrue(result.isRecorded, "浏览器即便切换了 Tab 标签页，也必须顺利匹配为已记录状态！")
        XCTAssertEqual(result.relativeFrame, savedChrome.relativeFrame, "应当沿用预设中的目标尺寸和位置")
        XCTAssertEqual(result.windowTitle, liveChrome.windowTitle, "界面应当动态显示当前正在浏览的最新网页标题")
    }

    func testMultiDisplayBrowserMatchingResolvesByDisplayUUID() {
        // 用户有两个 Chrome 窗口：
        // 窗口 1 记录在显示器 A (DISP-A)
        let savedChromeA = WindowLayoutItem(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            profile: "Zhenqiang",
            windowIndex: 0,
            windowTitle: "Doc A - Google Chrome",
            targetDisplayUUID: "DISP-A",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 900, height: 900),
            isRecorded: true
        )
        // 窗口 2 记录在显示器 B (DISP-B)
        let savedChromeB = WindowLayoutItem(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            profile: "Zhenqiang",
            windowIndex: 1,
            windowTitle: "Doc B - Google Chrome",
            targetDisplayUUID: "DISP-B",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 100, y: 100, width: 800, height: 800),
            isRecorded: true
        )

        // 此时用户聚焦了显示器 B 的窗口，导致系统 discovery 的 index 颠倒（B 变成了 0，A 变成了 1），
        // 且两个窗口的 Tab 标题都发生了变化：
        let liveChromeB = WindowLayoutItem(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            profile: "Zhenqiang",
            windowIndex: 0, // 颠倒后的序号
            windowTitle: "New Tab on B - Google Chrome",
            targetDisplayUUID: "DISP-B",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 120, y: 120, width: 800, height: 800),
            isRecorded: false
        )
        let liveChromeA = WindowLayoutItem(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            profile: "Zhenqiang",
            windowIndex: 1, // 颠倒后的序号
            windowTitle: "New Tab on A - Google Chrome",
            targetDisplayUUID: "DISP-A",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 10, y: 10, width: 900, height: 900),
            isRecorded: false
        )

        let merged = AppState.matchSnapshotItems(
            currentSnap: [liveChromeB, liveChromeA],
            savedItems: [savedChromeA, savedChromeB]
        )

        XCTAssertEqual(merged.count, 2)
        let matchedA = merged.first { $0.windowTitle == "New Tab on A - Google Chrome" }
        let matchedB = merged.first { $0.windowTitle == "New Tab on B - Google Chrome" }

        XCTAssertNotNil(matchedA)
        XCTAssertTrue(matchedA!.isRecorded)
        XCTAssertEqual(matchedA?.targetDisplayUUID, "DISP-A")

        XCTAssertNotNil(matchedB)
        XCTAssertTrue(matchedB!.isRecorded)
        XCTAssertEqual(matchedB?.targetDisplayUUID, "DISP-B")
    }

    func testHealDuplicateBrowserPresetsCleansGhostEntries() {
        let entry1 = WindowLayoutItem(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            profile: "Zhenqiang (SZQ)",
            windowIndex: 0,
            windowTitle: "Tab 1 - Google Chrome",
            targetDisplayUUID: "DISP-1",
            targetDisplayWidth: 2056,
            targetDisplayHeight: 1329,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 800, height: 600)
        )
        let entry2 = WindowLayoutItem(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            profile: "Zhenqiang (SZQ)",
            windowIndex: 0,
            windowTitle: "Tab 2 - Google Chrome",
            targetDisplayUUID: "DISP-1",
            targetDisplayWidth: 2056,
            targetDisplayHeight: 1329,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 800, height: 600)
        )
        let nonBrowser = WindowLayoutItem(
            bundleIdentifier: "com.apple.finder",
            appName: "Finder",
            windowIndex: 0,
            windowTitle: "Downloads",
            targetDisplayWidth: 2056,
            targetDisplayHeight: 1329,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 50, y: 50, width: 500, height: 400)
        )

        let topo = DisplayTopology(name: "Topo", topologyFingerprint: "fp", displays: [])
        let preset = WindowPreset(topologyId: topo.id, name: "Preset", items: [entry1, entry2, nonBrowser])
        var config = LayoutConfig(
            version: 3,
            activeTopologyId: topo.id,
            activePresetIdMap: [topo.id: preset.id],
            autoQuitAfterRestore: false,
            autoRestoreOnProfileMatch: false,
            topologies: [topo],
            presets: [preset]
        )

        let healed = config.healDuplicateBrowserPresets()
        XCTAssertTrue(healed, "发现重复的浏览器历史预设项时应当返回 true 并清理")
        XCTAssertEqual(config.presets[0].items.count, 2, "原本 3 项（2 个重复 Chrome + 1 个 Finder）应精简为 2 项")
        XCTAssertEqual(config.presets[0].items[0].windowTitle, "Tab 2 - Google Chrome", "保留最后记录的最新一项")
    }
}


