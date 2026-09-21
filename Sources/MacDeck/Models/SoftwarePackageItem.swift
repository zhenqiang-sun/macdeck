import Foundation

public enum PackageSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case brewCask     = "brewCask"     // 桌面应用
    case brewFormula  = "brewFormula"  // 命令行工具
    case appStore     = "appStore"     // Mac App Store
    case npmGlobal    = "npmGlobal"    // Node.js 全局模块
    case volta        = "volta"        // Volta 全局包
    case pipx         = "pipx"         // Python 工具
    case cargo        = "cargo"        // Rust Cargo 工具

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .brewCask: return "桌面应用"
        case .brewFormula: return "命令行"
        case .appStore: return "App Store"
        case .npmGlobal: return "npm 全局"
        case .volta: return "Volta"
        case .pipx: return "Python"
        case .cargo: return "Cargo"
        }
    }

    public var icon: String {
        switch self {
        case .brewCask: return "macwindow"
        case .brewFormula: return "terminal"
        case .appStore: return "apple.logo"
        case .npmGlobal: return "shippingbox"
        case .volta: return "bolt.fill"
        case .pipx: return "chevron.left.forwardslash.chevron.right"
        case .cargo: return "cube.box"
        }
    }
}

public enum PackageStatus: Equatable {
    case available
    case upgrading
    case upgraded
    case failed(message: String)
}

public struct VersionHelper {
    public static func extractMajorVersion(_ versionString: String) -> Int? {
        let cleaned = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned != "最新" else { return nil }

        var str = cleaned
        if str.lowercased().hasPrefix("v") {
            str.removeFirst()
        }

        let parts = str.components(separatedBy: CharacterSet(charactersIn: ".-_"))
        guard let firstPart = parts.first, let major = Int(firstPart) else {
            return nil
        }
        return major
    }

    public static func isMajorUpdate(current: String, latest: String) -> Bool {
        guard let curMajor = extractMajorVersion(current),
              let latMajor = extractMajorVersion(latest) else {
            return false
        }
        return latMajor > curMajor
    }
}

public struct SoftwarePackageItem: Identifiable, Equatable {
    public let id: String
    public let rawName: String
    public let displayName: String
    public var currentVersion: String
    public var latestVersion: String
    public let source: PackageSource
    public var isSelected: Bool
    public var status: PackageStatus

    public var hasUpdate: Bool {
        return latestVersion != currentVersion && !latestVersion.isEmpty && latestVersion != "最新"
    }

    public var isPinned: Bool {
        UpdateSettingsStore.shared.isPinned(rawName: rawName)
    }

    public var isIgnored: Bool {
        UpdateSettingsStore.shared.ignoredVersion(for: rawName) == latestVersion
    }

    public var isMajorUpdate: Bool {
        VersionHelper.isMajorUpdate(current: currentVersion, latest: latestVersion)
    }

    public init(
        id: String,
        rawName: String,
        displayName: String,
        currentVersion: String,
        latestVersion: String,
        source: PackageSource,
        isSelected: Bool = true,
        status: PackageStatus = .available
    ) {
        self.id = id
        self.rawName = rawName
        self.displayName = displayName
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.source = source
        self.isSelected = isSelected
        self.status = status
    }
}

import AppKit

public enum AppIconHelper {
    private static var cache: [String: NSImage] = [:]

    public static func icon(for item: SoftwarePackageItem) -> NSImage? {
        if let cached = cache[item.id] { return cached }

        guard item.source == .brewCask || item.source == .appStore else { return nil }

        let fileManager = FileManager.default
        let appDirs = ["/Applications", ("~/Applications" as NSString).expandingTildeInPath, "/System/Applications"]

        let targets = [
            "\(item.displayName).app",
            "\(item.rawName).app",
            "\(item.displayName.replacingOccurrences(of: " ", with: "")).app"
        ]

        for dir in appDirs {
            for target in targets {
                let path = (dir as NSString).appendingPathComponent(target)
                if fileManager.fileExists(atPath: path) {
                    let img = NSWorkspace.shared.icon(forFile: path)
                    cache[item.id] = img
                    return img
                }
            }

            if let contents = try? fileManager.contentsOfDirectory(atPath: dir) {
                for file in contents where file.hasSuffix(".app") {
                    let appName = (file as NSString).deletingPathExtension.lowercased()
                    let targetName = item.displayName.lowercased()
                    let rawName = item.rawName.lowercased()
                    if appName == targetName ||
                       appName == rawName ||
                       appName.replacingOccurrences(of: " ", with: "") == rawName.replacingOccurrences(of: "-", with: "") {
                        let path = (dir as NSString).appendingPathComponent(file)
                        let img = NSWorkspace.shared.icon(forFile: path)
                        cache[item.id] = img
                        return img
                    }
                }
            }
        }
        return nil
    }
}

