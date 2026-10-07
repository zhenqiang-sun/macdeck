import Foundation

public final class SystemInfoCacheStore: @unchecked Sendable {
    public static let shared = SystemInfoCacheStore()

    private let cacheURL: URL

    public init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacDeck")
        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.cacheURL = appSupport.appendingPathComponent("system_info_cache.json")
    }

    public init(customURL: URL) {
        self.cacheURL = customURL
    }

    public func loadCachedReport() -> SystemInfoReport? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(SystemInfoReport.self, from: data)
    }

    public func saveCachedReport(_ report: SystemInfoReport) {
        if let data = try? JSONEncoder().encode(report) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }

    public func clearCache() {
        try? FileManager.default.removeItem(at: cacheURL)
    }
}
