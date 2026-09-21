import Foundation

public final class LayoutStore {
    public static let shared = LayoutStore()

    private let fileManager = FileManager.default
    private let configURL: URL

    public init(storageDirectory: URL? = nil) {
        let dir: URL
        if let customDir = storageDirectory {
            dir = customDir
        } else {
            let home = fileManager.homeDirectoryForCurrentUser
            dir = home.appendingPathComponent(".config/macdeck", isDirectory: true)
        }
        self.configURL = dir.appendingPathComponent("layouts.json")
    }

    public func load() -> LayoutConfig {
        guard fileManager.fileExists(atPath: configURL.path) else {
            return LayoutConfig()
        }
        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            if var v3 = try? decoder.decode(LayoutConfig.self, from: data), v3.version >= 3 {
                let hasLegacyFormat = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["displayAliases"] == nil
                let healed = v3.healTopologyFingerprints()
                if hasLegacyFormat || healed {
                    save(config: v3)
                }
                return v3
            }
            var migrated = LayoutConfig.migrateIfNecessary(from: data)
            _ = migrated.healTopologyFingerprints()
            save(config: migrated)
            return migrated
        } catch {
            print("[LayoutStore] Failed to load config: \(error)")
            return LayoutConfig()
        }
    }

    public func save(config: LayoutConfig) {
        do {
            let dir = configURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: .atomic)
        } catch {
            print("[LayoutStore] Failed to save config: \(error)")
        }
    }
}
