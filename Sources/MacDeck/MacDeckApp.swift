import SwiftUI
import AppKit

@main
struct MacDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let args = CommandLine.arguments

        if args.contains("--restore") {
            handleRestore()
        } else if args.contains("--snapshot") {
            handleSnapshot()
        } else if args.contains("--status") {
            handleStatus()
        }
    }

    var body: some Scene {
        Window("MacDeck", id: "main") {
            MainWindowView()
        }
        .windowResizability(.contentSize)
    }

    private func handleRestore() {
        let store = LayoutStore.shared
        let windowManager = WindowManager.shared
        let savedConfig = store.load()
        var restoredCount = 0

        for item in savedConfig.items {
            if windowManager.restore(item: item) {
                restoredCount += 1
            }
        }

        print("✅ 窗口归位完成：成功复原 \(restoredCount) 个窗口")
        exit(0)
    }

    private func handleSnapshot() {
        let store = LayoutStore.shared
        let windowManager = WindowManager.shared
        let displayManager = DisplayManager.shared
        var config = store.load()
        let aliasMap = config.displayAliases
        let items = windowManager.captureSnapshot(displayAliases: aliasMap)
        var displays = displayManager.getCurrentDisplays()
        for i in 0..<displays.count {
            if let a = aliasMap[displays[i].uuid] {
                displays[i].alias = a
            }
        }
        config.items = items
        config.displays = displays
        store.save(config: config)
        print("📸 成功快照当前 \(items.count) 个窗口并保存至配置")
        exit(0)
    }

    private func handleStatus() {
        let displayManager = DisplayManager.shared
        let windowManager = WindowManager.shared
        let store = LayoutStore.shared

        let displays = displayManager.getCurrentDisplays()
        let items = windowManager.captureSnapshot()
        let config = store.load()
        let savedIds = Set(config.items.map { $0.id })

        print("🖥️ 当前检测到 \(displays.count) 台显示器:")
        for d in displays {
            print("  - \(d.name) (\(Int(d.boundsWidth))×\(Int(d.boundsHeight))) \(d.isMain ? "[主屏]" : "")")
        }

        print("\n🪟 当前检测到 \(items.count) 个活跃窗口:")
        for item in items {
            let profileStr = item.profile != nil ? " [Profile: \(item.profile!)]" : ""
            let statusStr = savedIds.contains(item.id) ? "已记录" : "未记录"
            print("  - \(item.appName)\(profileStr): \(statusStr) (在 \(item.targetDisplayIsMain ? "主屏" : "副屏"))")
        }
        exit(0)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        SoftwareUpdateBackgroundChecker.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
