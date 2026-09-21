import AppKit
import ApplicationServices

public final class WindowManager {
    public static let shared = WindowManager()

    public init() {}

    public static func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    public static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public struct DiscoveredWindow {
        public let app: NSRunningApplication
        public let axElement: AXUIElement?
        public let title: String
        public let profile: String?
        public let frame: CGRect
        public let isMinimized: Bool
        public let isFullScreen: Bool
        public let displayUUID: String?

        public init(
            app: NSRunningApplication,
            axElement: AXUIElement? = nil,
            title: String,
            profile: String?,
            frame: CGRect,
            isMinimized: Bool,
            isFullScreen: Bool = false,
            displayUUID: String? = nil
        ) {
            self.app = app
            self.axElement = axElement
            self.title = title
            self.profile = profile
            self.frame = frame
            self.isMinimized = isMinimized
            self.isFullScreen = isFullScreen
            self.displayUUID = displayUUID
        }
    }

    private typealias SLSMainConnectionIDFunc = @convention(c) () -> Int32
    private typealias CGSCopyManagedDisplaySpacesFunc = @convention(c) (Int32) -> CFArray

    private struct FullscreenSpaceTile {
        let pid: pid_t
        let appName: String
        let windowTitle: String
        let displayUUID: String
        let rect: CGRect
    }

    private func discoverFullscreenSpaces() -> [FullscreenSpaceTile] {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let mainConnSym = dlsym(handle, "SLSMainConnectionID"),
              let spacesSym = dlsym(handle, "CGSCopyManagedDisplaySpaces") else {
            return []
        }
        let mainConnFn = unsafeBitCast(mainConnSym, to: SLSMainConnectionIDFunc.self)
        let spacesFn = unsafeBitCast(spacesSym, to: CGSCopyManagedDisplaySpacesFunc.self)
        let cid = mainConnFn()
        guard let displays = spacesFn(cid) as? [[String: Any]] else { return [] }

        var tiles: [FullscreenSpaceTile] = []
        for display in displays {
            let displayUUID = display["Display Identifier"] as? String ?? ""
            guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            for space in spaces {
                let spaceType = space["type"] as? Int ?? 0
                if spaceType == 4 { // Fullscreen Space
                    if let tileMgr = space["TileLayoutManager"] as? [String: Any],
                       let tileSpaces = tileMgr["TileSpaces"] as? [[String: Any]] {
                        for tile in tileSpaces {
                            let pid = tile["pid"] as? pid_t ?? 0
                            let appName = tile["appName"] as? String ?? ""
                            let name = tile["name"] as? String ?? ""
                            let rectDict = tile["TileRect"] as? [String: Any] ?? [:]
                            let w = rectDict["Width"] as? Double ?? 0
                            let h = rectDict["Height"] as? Double ?? 0
                            let x = rectDict["X"] as? Double ?? 0
                            let y = rectDict["Y"] as? Double ?? 0
                            tiles.append(FullscreenSpaceTile(
                                pid: pid,
                                appName: appName,
                                windowTitle: name,
                                displayUUID: displayUUID,
                                rect: CGRect(x: x, y: y, width: w, height: h)
                            ))
                        }
                    }
                }
            }
        }
        return tiles
    }

    public func discoverWindows() -> [DiscoveredWindow] {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }

        let fullscreenTiles = discoverFullscreenSpaces()
        var results: [DiscoveredWindow] = []

        for app in apps {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsValue: AnyObject?
            _ = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

            var axWindows = (windowsValue as? [AXUIElement]) ?? []

            // 补充检查 AXMainWindow 和 AXFocusedWindow，防止虚拟桌面或全屏 Space 下窗口未在 AXWindows 包含
            var mainWinVal: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWinVal) == .success,
               let mainWin = mainWinVal as! AXUIElement? {
                if !axWindows.contains(where: { CFEqual($0, mainWin) }) {
                    axWindows.append(mainWin)
                }
            }
            var focusedWinVal: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWinVal) == .success,
               let focusedWin = focusedWinVal as! AXUIElement? {
                if !axWindows.contains(where: { CFEqual($0, focusedWin) }) {
                    axWindows.append(focusedWin)
                }
            }

            // 对于特定远程桌面应用（如 Windows App），检查 Window 菜单唤醒会话窗口
            if axWindows.isEmpty && app.bundleIdentifier == "com.microsoft.rdc.macos" {
                var menuBarVal: AnyObject?
                if AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarVal) == .success,
                   let menuBar = menuBarVal as! AXUIElement? {
                    var menuChildrenVal: AnyObject?
                    _ = AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &menuChildrenVal)
                }
                var retryWinsVal: AnyObject?
                if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &retryWinsVal) == .success,
                   let retryWins = retryWinsVal as? [AXUIElement], !retryWins.isEmpty {
                    axWindows = retryWins
                }
            }

            guard !axWindows.isEmpty else { continue }

            for win in axWindows {
                var titleVal: AnyObject?
                AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleVal)
                let title = (titleVal as? String) ?? ""

                var posVal: AnyObject?
                var sizeVal: AnyObject?
                AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posVal)
                AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeVal)

                var point = CGPoint.zero
                var size = CGSize.zero
                if let p = posVal, CFGetTypeID(p) == AXValueGetTypeID() {
                    AXValueGetValue(p as! AXValue, .cgPoint, &point)
                }
                if let s = sizeVal, CFGetTypeID(s) == AXValueGetTypeID() {
                    AXValueGetValue(s as! AXValue, .cgSize, &size)
                }

                guard size.width > 100 && size.height > 100 else { continue }

                var minVal: AnyObject?
                AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minVal)
                let isMinimized = (minVal as? Bool) ?? false

                var fsVal: AnyObject?
                AXUIElementCopyAttributeValue(win, "AXFullScreen" as CFString, &fsVal)
                var isFullScreen = (fsVal as? Bool) ?? false

                // 关联全屏 Tile 确定精准所属 displayUUID
                var matchedDisplayUUID: String? = nil
                if let tile = fullscreenTiles.first(where: {
                    $0.pid == app.processIdentifier && (
                        (!title.isEmpty && $0.windowTitle == title) ||
                        (abs(size.width - $0.rect.width) <= 10.0 && abs(size.height - $0.rect.height) <= 10.0)
                    )
                }) {
                    isFullScreen = true
                    matchedDisplayUUID = tile.displayUUID
                }

                // 全屏保底判定：若系统未返回 AXFullScreen，但窗口尺寸与所在物理屏幕尺寸吻合（允许 5pt 误差），判定为全屏
                if !isFullScreen {
                    let midPoint = CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2)
                    if let screen = DisplayManager.shared.findScreenContaining(point: midPoint) {
                        let cgBounds = DisplayManager.getScreenCGBounds(for: screen)
                        if abs(size.width - cgBounds.width) <= 5.0 && abs(size.height - cgBounds.height) <= 5.0 {
                            isFullScreen = true
                            let sNum = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
                            matchedDisplayUUID = DisplayManager.getDisplayUUID(for: sNum)
                        }
                    }
                }

                // 若未匹配到 displayUUID，通过 midPoint 获取所在物理屏幕 UUID
                if matchedDisplayUUID == nil {
                    let midPoint = CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2)
                    if let screen = DisplayManager.shared.findScreenContaining(point: midPoint) {
                        let sNum = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
                        matchedDisplayUUID = DisplayManager.getDisplayUUID(for: sNum)
                    }
                }

                var profile: String? = nil
                if app.bundleIdentifier == "com.google.Chrome" {
                    let parsed = ChromeProfileParser.parse(windowTitle: title)
                    profile = parsed.profile
                }

                results.append(DiscoveredWindow(
                    app: app,
                    axElement: win,
                    title: title,
                    profile: profile,
                    frame: CGRect(origin: point, size: size),
                    isMinimized: isMinimized,
                    isFullScreen: isFullScreen,
                    displayUUID: matchedDisplayUUID
                ))
            }
        }

        // 补充发现处于非活动虚拟桌面（Inactive Fullscreen Space）中的全屏窗口（如后台 Finder、Windows App 等）
        let runningApps = NSWorkspace.shared.runningApplications
        for tile in fullscreenTiles {
            // 如果 results 中已存在该进程且标题相同的全屏窗口，说明已通过活跃 AX 捕获，跳过避免重复
            let alreadyFound = results.contains { win in
                win.app.processIdentifier == tile.pid && (
                    (!win.title.isEmpty && win.title == tile.windowTitle) ||
                    (win.isFullScreen && abs(win.frame.origin.x - tile.rect.origin.x) < 5.0 && abs(win.frame.origin.y - tile.rect.origin.y) < 5.0)
                )
            }
            if alreadyFound { continue }

            guard let app = runningApps.first(where: { $0.processIdentifier == tile.pid }) else { continue }

            results.append(DiscoveredWindow(
                app: app,
                axElement: nil,
                title: tile.windowTitle,
                profile: nil,
                frame: tile.rect,
                isMinimized: false,
                isFullScreen: true,
                displayUUID: tile.displayUUID
            ))
        }

        return results
    }

    public func captureSnapshot(displayAliases: [String: String] = [:]) -> [WindowLayoutItem] {
        let windows = discoverWindows()
        var items: [WindowLayoutItem] = []
        var indexMap: [String: Int] = [:]

        for win in windows {
            guard let bundleId = win.app.bundleIdentifier, let appName = win.app.localizedName else { continue }

            // 准确定位屏幕：优先通过 win.displayUUID，找不到再通过 centerPoint
            let screen: NSScreen = {
                if let uuid = win.displayUUID, !uuid.isEmpty {
                    for s in NSScreen.screens {
                        let sNum = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
                        if DisplayManager.getDisplayUUID(for: sNum) == uuid {
                            return s
                        }
                    }
                }
                let centerPoint = CGPoint(x: win.frame.midX, y: win.frame.midY)
                return DisplayManager.shared.findScreenContaining(point: centerPoint) ?? NSScreen.main ?? NSScreen.screens.first!
            }()

            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
            let screenUUID = DisplayManager.getDisplayUUID(for: screenNumber)
            let alias = displayAliases[screenUUID]
            let rel = DisplayManager.shared.relativeFrame(from: win.frame, on: screen)

            let groupKey = "\(bundleId):\(win.profile ?? "default")"
            let currentIndex = indexMap[groupKey, default: 0]
            indexMap[groupKey] = currentIndex + 1

            let cgBounds = DisplayManager.getScreenCGBounds(for: screen)
            let item = WindowLayoutItem(
                bundleIdentifier: bundleId,
                appName: appName,
                profile: win.profile,
                windowIndex: currentIndex,
                windowTitle: win.title.isEmpty ? nil : win.title,
                targetDisplayUUID: screenUUID,
                targetDisplayAlias: alias,
                targetDisplayWidth: cgBounds.width,
                targetDisplayHeight: cgBounds.height,
                targetDisplayIsMain: screen == NSScreen.main,
                relativeFrame: rel,
                isRecorded: true,
                isFullScreen: win.isFullScreen,
                isMinimized: win.isMinimized
            )
            items.append(item)
        }

        return items
    }

    public func restore(item: WindowLayoutItem, displayAliases: [String: String] = [:]) -> Bool {
        let windows = discoverWindows()
        let candidates = windows.filter { win in
            guard win.app.bundleIdentifier == item.bundleIdentifier else { return false }
            if let targetProfile = item.profile {
                return win.profile == targetProfile
            }
            return true
        }

        guard !candidates.isEmpty else {
            return false
        }

        // 匹配优先级：
        // 1. 若指定了 windowTitle 且非空，优先匹配标题完全相同的窗口（如特定远程桌面会话名、文档名等）
        // 2. 否则根据 windowIndex 索引匹配
        // 3. 最后回退到候选列表第一个
        let targetWindow: DiscoveredWindow
        if let targetTitle = item.windowTitle, !targetTitle.isEmpty,
           let titleMatch = candidates.first(where: { $0.title == targetTitle }) {
            targetWindow = titleMatch
        } else if item.windowIndex < candidates.count {
            targetWindow = candidates[item.windowIndex]
        } else {
            targetWindow = candidates.first!
        }

        let (targetFrame, targetScreen) = DisplayManager.shared.resolveAbsoluteFrame(
            relative: item.relativeFrame,
            targetUUID: item.targetDisplayUUID,
            targetAlias: item.targetDisplayAlias,
            targetWidth: item.targetDisplayWidth,
            targetHeight: item.targetDisplayHeight,
            targetIsMain: item.targetDisplayIsMain,
            displayAliases: displayAliases
        )

        let targetScreenNumber = targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
        let targetScreenUUID = DisplayManager.getDisplayUUID(for: targetScreenNumber)
        let targetScreenCGBounds = DisplayManager.getScreenCGBounds(for: targetScreen)

        // 1. 判断窗口当前全屏状态
        var isCurrentlyFSVal: AnyObject?
        if let elem = targetWindow.axElement {
            AXUIElementCopyAttributeValue(elem, "AXFullScreen" as CFString, &isCurrentlyFSVal)
        }
        let isCurrentlyFullScreen = (isCurrentlyFSVal as? Bool) ?? targetWindow.isFullScreen

        // 2. 判断目标是否期望全屏
        let shouldBeFullScreen: Bool = {
            if let fs = item.isFullScreen { return fs }
            // 兼容历史配置：若记录的窗口宽高覆盖目标屏幕的大部分区域，判定为全屏期望
            return item.relativeFrame.x <= 20 &&
                   item.relativeFrame.y <= 40 &&
                   item.relativeFrame.width >= (item.targetDisplayWidth - 40) &&
                   item.relativeFrame.height >= (item.targetDisplayHeight - 80)
        }()

        // 3. 判断是否已经在目标屏幕上
        let isAlreadyOnTargetScreen: Bool = {
            // 优先依据精准 displayUUID 比对
            if let curUUID = targetWindow.displayUUID, !curUUID.isEmpty {
                return curUUID == targetScreenUUID
            }
            // 依据几何中心点判定
            let currentCenter = CGPoint(x: targetWindow.frame.midX, y: targetWindow.frame.midY)
            if let currentScreen = DisplayManager.shared.findScreenContaining(point: currentCenter) {
                if currentScreen == targetScreen { return true }
            }
            // 容错兜底：若当前已全屏且窗口尺寸与目标屏幕吻合（允许 10pt 误差）
            if isCurrentlyFullScreen &&
               abs(targetWindow.frame.width - targetScreenCGBounds.width) <= 10.0 &&
               abs(targetWindow.frame.height - targetScreenCGBounds.height) <= 10.0 {
                return true
            }
            return false
        }()

        // 核心保护：当前处于全屏时，若已在目标屏幕且期望全屏，无需多余操作，直接返回成功！
        // 彻底杜绝原本已全屏的窗口被错误触发退出全屏 Space 的问题！
        if isCurrentlyFullScreen && isAlreadyOnTargetScreen && shouldBeFullScreen {
            return true
        }

        // 若需要调整位置或切换全屏形态，但 axElement 为空（因为处于后台 Space），尝试唤醒该应用挂载 AX 树
        var element = targetWindow.axElement
        if element == nil {
            targetWindow.app.activate(options: .activateIgnoringOtherApps)
            let appElem = AXUIElementCreateApplication(targetWindow.app.processIdentifier)
            let deadline = Date().addingTimeInterval(0.8)
            while Date() < deadline && element == nil {
                var winsVal: AnyObject?
                if AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &winsVal) == .success,
                   let wins = winsVal as? [AXUIElement], !wins.isEmpty {
                    for w in wins {
                        var t: AnyObject?
                        _ = AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &t)
                        if (t as? String) == targetWindow.title {
                            element = w
                            break
                        }
                    }
                    if element == nil { element = wins.first }
                }
                if element == nil {
                    usleep(50_000)
                }
            }
        }

        guard let axElem = element else {
            return false
        }

        // 4. 当前处于全屏时，安全退出全屏并轮询等待系统动画彻底完成
        if isCurrentlyFullScreen {
            AXUIElementSetAttributeValue(axElem, "AXFullScreen" as CFString, kCFBooleanFalse)
            // 轮询等待 macOS Space 退出动画完成（AXFullScreen 变为 false）
            let exitDeadline = Date().addingTimeInterval(1.2)
            while Date() < exitDeadline {
                usleep(50_000) // 50ms 轮询检测
                var fsVal: AnyObject?
                let status = AXUIElementCopyAttributeValue(axElem, "AXFullScreen" as CFString, &fsVal)
                if status == .success, let isFS = fsVal as? Bool, !isFS {
                    break // 退出全屏 Space 动画完成！
                }
            }
            usleep(80_000) // 额外 80ms 让 WindowServer 稳定
        }

        // 5. 最小化状态处理
        let shouldBeMinimized = item.isMinimized ?? false

        if targetWindow.isMinimized && !shouldBeMinimized {
            // 当前处于最小化，但目标期望在桌面展示：从 Dock 中唤醒
            AXUIElementSetAttributeValue(axElem, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            let unminDeadline = Date().addingTimeInterval(0.6)
            while Date() < unminDeadline {
                usleep(40_000)
                var minVal: AnyObject?
                if AXUIElementCopyAttributeValue(axElem, kAXMinimizedAttribute as CFString, &minVal) == .success,
                   let isMin = minVal as? Bool, !isMin {
                    break
                }
            }
        }

        // 6. 移动与尺寸定位：采用“先安全尺寸 -> 再定位 -> 再校准”三步走
        var newPoint = targetFrame.origin
        var newSize = targetFrame.size

        if let sizeVal = AXValueCreate(.cgSize, &newSize) {
            AXUIElementSetAttributeValue(axElem, kAXSizeAttribute as CFString, sizeVal)
        }
        if let posVal = AXValueCreate(.cgPoint, &newPoint) {
            AXUIElementSetAttributeValue(axElem, kAXPositionAttribute as CFString, posVal)
        }
        // 尺寸调整后再次校准位置，防止因窗口初始尺寸越界引发的系统自动吸附偏差
        if let sizeVal = AXValueCreate(.cgSize, &newSize) {
            AXUIElementSetAttributeValue(axElem, kAXSizeAttribute as CFString, sizeVal)
        }
        if let posVal = AXValueCreate(.cgPoint, &newPoint) {
            AXUIElementSetAttributeValue(axElem, kAXPositionAttribute as CFString, posVal)
        }

        // 7. 若目标状态期望全屏，在目标屏幕就位后切入全屏 Space，并提供闭环验证与重试
        if shouldBeFullScreen {
            usleep(120_000) // 120ms 缓冲让窗口在目标屏幕完成位置锁定
            AXUIElementSetAttributeValue(axElem, "AXFullScreen" as CFString, kCFBooleanTrue)

            // 闭环验证机制：等待 220ms 检查 AXFullScreen 是否生效，若未生效补发一次，确保单次点击 100% 成功
            usleep(220_000)
            var fsCheck: AnyObject?
            if AXUIElementCopyAttributeValue(axElem, "AXFullScreen" as CFString, &fsCheck) == .success {
                let isFS = (fsCheck as? Bool) ?? false
                if !isFS {
                    AXUIElementSetAttributeValue(axElem, "AXFullScreen" as CFString, kCFBooleanTrue)
                }
            }
        } else if shouldBeMinimized {
            // 若目标状态期望最小化，就位后缩入 Dock
            usleep(80_000)
            AXUIElementSetAttributeValue(axElem, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        }

        return true
    }
}
