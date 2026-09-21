import AppKit
import CoreGraphics
import CryptoKit

public final class DisplayManager {
    public static let shared = DisplayManager()

    private var screenObserverTokens: [NSObjectProtocol] = []
    private var debounceTimer: DispatchWorkItem?

    public init() {}

    deinit {
        stopObservingScreenChanges()
    }

    public static func getDisplayUUID(for displayID: CGDirectDisplayID) -> String {
        if let cfuuid = CGDisplayCreateUUIDFromDisplayID(displayID) {
            let uuid = CFUUIDCreateString(nil, cfuuid.takeRetainedValue()) as String
            return uuid
        }
        return "DISPLAY-\(displayID)"
    }

    /// 获取屏幕在全局 CoreGraphics (Quartz / AX) 统一坐标系下的几何矩形
    public static func getScreenCGBounds(for screen: NSScreen) -> CGRect {
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
        return CGDisplayBounds(screenNumber)
    }

    public func getCurrentDisplays() -> [DisplayInfo] {
        let primaryScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first
        return NSScreen.screens.enumerated().map { index, screen in
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? UInt32(index + 1)
            let uuid = Self.getDisplayUUID(for: screenNumber)
            let name = screen.localizedName
            let cgBounds = CGDisplayBounds(screenNumber)
            let isPrimary = (screen == primaryScreen) || (cgBounds.origin.x == 0 && cgBounds.origin.y == 0)

            return DisplayInfo(
                id: screenNumber,
                uuid: uuid,
                name: name,
                isMain: isPrimary,
                boundsWidth: cgBounds.width,
                boundsHeight: cgBounds.height,
                originX: cgBounds.origin.x,
                originY: cgBounds.origin.y
            )
        }
    }

    public static func computeTopologyFingerprint(displays: [DisplayInfo]) -> String {
        // Deterministic sort by UUID, then originX
        let sorted = displays.sorted {
            if $0.uuid != $1.uuid { return $0.uuid < $1.uuid }
            return $0.originX < $1.originX
        }
        let rawKey = sorted.map { d in
            "\(d.uuid):\(Int(d.boundsWidth))x\(Int(d.boundsHeight)):\(d.isMain ? "main" : "sub")"
        }.joined(separator: "|")

        let hash = SHA256.hash(data: Data(rawKey.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    public func startObservingScreenChanges(onChange: @escaping () -> Void) {
        stopObservingScreenChanges()

        let handler: (Notification) -> Void = { [weak self] _ in
            self?.debounceTimer?.cancel()
            let workItem = DispatchWorkItem {
                onChange()
            }
            self?.debounceTimer = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        }

        let token1 = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main,
            using: handler
        )
        let token2 = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main,
            using: handler
        )
        let token3 = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main,
            using: handler
        )

        screenObserverTokens = [token1, token2, token3]
    }

    public func stopObservingScreenChanges() {
        for token in screenObserverTokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        screenObserverTokens.removeAll()
        debounceTimer?.cancel()
        debounceTimer = nil
    }

    public func findScreenContaining(point: CGPoint) -> NSScreen? {
        return NSScreen.screens.first { screen in
            let cgBounds = Self.getScreenCGBounds(for: screen)
            return cgBounds.contains(point)
        } ?? NSScreen.main
    }

    public func relativeFrame(from absoluteFrame: CGRect, on screen: NSScreen) -> RelativeRect {
        let cgBounds = Self.getScreenCGBounds(for: screen)
        let relX = absoluteFrame.origin.x - cgBounds.origin.x
        let relY = absoluteFrame.origin.y - cgBounds.origin.y
        return RelativeRect(x: relX, y: relY, width: absoluteFrame.width, height: absoluteFrame.height)
    }

    public func resolveAbsoluteFrame(
        relative: RelativeRect,
        targetUUID: String? = nil,
        targetAlias: String? = nil,
        targetWidth: Double,
        targetHeight: Double,
        targetIsMain: Bool,
        displayAliases: [String: String] = [:]
    ) -> (CGRect, NSScreen) {
        let screens = NSScreen.screens
        var matchedScreen: NSScreen?

        // Tier 1: Match by hardware UUID
        if let uuid = targetUUID, !uuid.isEmpty {
            matchedScreen = screens.first { screen in
                let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
                return Self.getDisplayUUID(for: id) == uuid
            }
        }

        // Tier 2: Match by Display Alias
        if matchedScreen == nil, let alias = targetAlias, !alias.isEmpty {
            matchedScreen = screens.first { screen in
                let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
                let screenUUID = Self.getDisplayUUID(for: id)
                return displayAliases[screenUUID] == alias
            }
        }

        // Tier 3: Geometry & isMain fallback
        if matchedScreen == nil {
            matchedScreen = screens.first { screen in
                let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
                let cgBounds = CGDisplayBounds(id)
                if targetIsMain && screen == NSScreen.main { return true }
                return abs(cgBounds.width - targetWidth) < 2.0 && abs(cgBounds.height - targetHeight) < 2.0
            }
        }

        if matchedScreen == nil {
            matchedScreen = targetIsMain ? NSScreen.main : (screens.first(where: { $0 != NSScreen.main }) ?? NSScreen.main)
        }

        let targetScreen = matchedScreen ?? NSScreen.main ?? screens.first!
        let targetCGBounds = Self.getScreenCGBounds(for: targetScreen)

        let absX = targetCGBounds.origin.x + relative.x
        let absY = targetCGBounds.origin.y + relative.y
        let candidate = CGRect(x: absX, y: absY, width: relative.width, height: relative.height)

        let displayInfo = DisplayInfo(
            id: targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0,
            uuid: targetUUID ?? "",
            name: targetScreen.localizedName,
            isMain: targetScreen == NSScreen.main,
            boundsWidth: targetCGBounds.width,
            boundsHeight: targetCGBounds.height,
            originX: targetCGBounds.origin.x,
            originY: targetCGBounds.origin.y
        )

        let clamped = Self.clampToScreen(rect: candidate, screen: displayInfo)
        return (clamped, targetScreen)
    }

    public func resolveAbsoluteFrame(relative: RelativeRect, targetWidth: Double, targetHeight: Double, targetIsMain: Bool) -> (CGRect, NSScreen) {
        return resolveAbsoluteFrame(
            relative: relative,
            targetUUID: nil,
            targetAlias: nil,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            targetIsMain: targetIsMain,
            displayAliases: [:]
        )
    }

    public static func clampToScreen(rect: CGRect, screen: DisplayInfo) -> CGRect {
        var w = min(rect.width, screen.boundsWidth)
        var h = min(rect.height, screen.boundsHeight)
        if w <= 0 { w = 800 }
        if h <= 0 { h = 600 }

        var x = rect.origin.x
        var y = rect.origin.y

        let minX = screen.originX
        let maxX = screen.originX + screen.boundsWidth - w
        let minY = screen.originY
        let maxY = screen.originY + screen.boundsHeight - h

        x = max(minX, min(x, maxX))
        y = max(minY, min(y, maxY))

        return CGRect(x: x, y: y, width: w, height: h)
    }
}
