import Foundation

public struct UpdateSettings: Codable, Equatable {
    public var ignoredVersions: [String: String] = [:] // [rawName: version]
    public var pinnedPackages: [String] = []          // [rawName]
    public var autoCheckEnabled: Bool = true
    public var checkIntervalHours: Int = 24
    public var lastCheckTimestamp: Date? = nil

    public init(
        ignoredVersions: [String: String] = [:],
        pinnedPackages: [String] = [],
        autoCheckEnabled: Bool = true,
        checkIntervalHours: Int = 24,
        lastCheckTimestamp: Date? = nil
    ) {
        self.ignoredVersions = ignoredVersions
        self.pinnedPackages = pinnedPackages
        self.autoCheckEnabled = autoCheckEnabled
        self.checkIntervalHours = checkIntervalHours
        self.lastCheckTimestamp = lastCheckTimestamp
    }
}

public final class UpdateSettingsStore: @unchecked Sendable {
    public static let shared = UpdateSettingsStore()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.macdeck.update-settings", qos: .userInitiated)
    private var settings: UpdateSettings

    public init(fileURL: URL? = nil) {
        if let url = fileURL {
            self.fileURL = url
        } else {
            let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/macdeck")
            try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            self.fileURL = configDir.appendingPathComponent("update_settings.json")
        }

        if let data = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode(UpdateSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = UpdateSettings()
        }
    }

    public var autoCheckEnabled: Bool {
        queue.sync { settings.autoCheckEnabled }
    }

    public var checkIntervalHours: Int {
        queue.sync { settings.checkIntervalHours }
    }

    public var lastCheckTimestamp: Date? {
        queue.sync { settings.lastCheckTimestamp }
    }

    public func setAutoCheckEnabled(_ enabled: Bool) {
        queue.sync {
            settings.autoCheckEnabled = enabled
            saveInternal()
        }
    }

    public func setCheckIntervalHours(_ hours: Int) {
        queue.sync {
            settings.checkIntervalHours = max(1, hours)
            saveInternal()
        }
    }

    public func recordCheck(at date: Date = Date()) {
        queue.sync {
            settings.lastCheckTimestamp = date
            saveInternal()
        }
    }

    public func shouldPerformAutoCheck(now: Date = Date()) -> Bool {
        queue.sync {
            guard settings.autoCheckEnabled else { return false }
            guard let last = settings.lastCheckTimestamp else { return true }
            let intervalSeconds = Double(settings.checkIntervalHours) * 3600.0
            return now.timeIntervalSince(last) >= intervalSeconds
        }
    }

    public func shouldSkipUpdate(rawName: String, latestVersion: String) -> Bool {
        queue.sync {
            if settings.pinnedPackages.contains(rawName) {
                return true
            }
            if let ignored = settings.ignoredVersions[rawName], ignored == latestVersion {
                return true
            }
            return false
        }
    }

    public func isPinned(rawName: String) -> Bool {
        queue.sync {
            settings.pinnedPackages.contains(rawName)
        }
    }

    public func ignoredVersion(for rawName: String) -> String? {
        queue.sync {
            settings.ignoredVersions[rawName]
        }
    }

    public func ignoreVersion(rawName: String, version: String) {
        queue.sync {
            settings.ignoredVersions[rawName] = version
            saveInternal()
        }
    }

    public func unignore(rawName: String) {
        queue.sync {
            settings.ignoredVersions.removeValue(forKey: rawName)
            saveInternal()
        }
    }

    public func pinPackage(rawName: String) {
        queue.sync {
            if !settings.pinnedPackages.contains(rawName) {
                settings.pinnedPackages.append(rawName)
                saveInternal()
            }
        }
    }

    public func unpin(rawName: String) {
        queue.sync {
            settings.pinnedPackages.removeAll { $0 == rawName }
            saveInternal()
        }
    }

    private func saveInternal() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(settings) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
