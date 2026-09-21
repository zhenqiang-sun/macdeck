import Foundation

public struct CleanupItem: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let pathDescription: String
    public var sizeBytes: Int64
    public var isScanning: Bool
    public var isCleaning: Bool

    public var formattedSize: String {
        if isScanning { return "正在计算..." }
        if sizeBytes == 0 { return "0 B (无缓存)" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }

    public init(
        id: String,
        name: String,
        pathDescription: String,
        sizeBytes: Int64 = 0,
        isScanning: Bool = false,
        isCleaning: Bool = false
    ) {
        self.id = id
        self.name = name
        self.pathDescription = pathDescription
        self.sizeBytes = sizeBytes
        self.isScanning = isScanning
        self.isCleaning = isCleaning
    }
}
