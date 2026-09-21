import Foundation

public final class UpdateHistoryStore: @unchecked Sendable {
    public static let shared = UpdateHistoryStore()

    private let storageURL: URL
    private let maxCapacity: Int
    private let queue = DispatchQueue(label: "com.macdeck.updateHistoryStore", qos: .utility)

    public init(storageURL: URL? = nil, maxCapacity: Int = 500) {
        if let url = storageURL {
            self.storageURL = url
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dir = home.appendingPathComponent(".config/macdeck", isDirectory: true)
            self.storageURL = dir.appendingPathComponent("update_history.json")
        }
        self.maxCapacity = maxCapacity
    }

    public func addRecord(_ record: UpdateHistoryRecord) {
        addRecords([record])
    }

    public func addRecords(_ newRecords: [UpdateHistoryRecord]) {
        guard !newRecords.isEmpty else { return }
        queue.sync {
            var current = loadRecordsInternal()
            // New records added at the front (most recent first)
            current.insert(contentsOf: newRecords, at: 0)
            if current.count > maxCapacity {
                current = Array(current.prefix(maxCapacity))
            }
            saveRecordsInternal(current)
        }
    }

    public func loadRecords() -> [UpdateHistoryRecord] {
        queue.sync {
            loadRecordsInternal()
        }
    }

    public func clearHistory() {
        queue.sync {
            saveRecordsInternal([])
        }
    }

    public func exportJSON() -> String {
        let records = loadRecords()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    public func exportCSV() -> String {
        let records = loadRecords()
        var csv = "Timestamp,Package,Source,PreviousVersion,TargetVersion,Status,Command\n"
        let df = ISO8601DateFormatter()
        for r in records {
            let time = df.string(from: r.timestamp)
            let safePkg = escapeCSV(r.packageName)
            let safeSource = escapeCSV(r.source.displayName)
            let safePrev = escapeCSV(r.previousVersion)
            let safeTarget = escapeCSV(r.targetVersion)
            let status = r.status.rawValue
            let safeCmd = escapeCSV(r.command)
            csv += "\(time),\(safePkg),\(safeSource),\(safePrev),\(safeTarget),\(status),\(safeCmd)\n"
        }
        return csv
    }

    private func escapeCSV(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return text
    }

    private func loadRecordsInternal() -> [UpdateHistoryRecord] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return [] }
        guard let data = try? Data(contentsOf: storageURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([UpdateHistoryRecord].self, from: data)) ?? []
    }

    private func saveRecordsInternal(_ records: [UpdateHistoryRecord]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }

        let parentDir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try? data.write(to: storageURL, options: .atomic)
    }
}
