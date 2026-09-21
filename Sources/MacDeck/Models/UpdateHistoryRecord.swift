import Foundation

public enum UpdateRecordStatus: String, Codable, Sendable {
    case success
    case failed
}

public struct UpdateHistoryRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let packageId: String
    public let packageName: String
    public let source: PackageSource
    public let previousVersion: String
    public let targetVersion: String
    public let status: UpdateRecordStatus
    public let command: String
    public let outputLog: String
    public let rollbackHint: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        packageId: String,
        packageName: String,
        source: PackageSource,
        previousVersion: String,
        targetVersion: String,
        status: UpdateRecordStatus,
        command: String,
        outputLog: String,
        rollbackHint: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.packageId = packageId
        self.packageName = packageName
        self.source = source
        self.previousVersion = previousVersion
        self.targetVersion = targetVersion
        self.status = status
        self.command = command
        self.outputLog = outputLog
        self.rollbackHint = rollbackHint
    }
}

public enum RollbackHelper {
    public static func generateHint(source: PackageSource, name: String, previousVersion: String) -> String? {
        guard !previousVersion.isEmpty, previousVersion != "未知" else { return nil }
        switch source {
        case .brewFormula:
            return "brew install \(name)@\(previousVersion)"
        case .brewCask:
            return "brew install --cask \(name)"
        case .npmGlobal:
            return "npm install -g \(name)@\(previousVersion)"
        case .pipx:
            return "pipx install \(name)==\(previousVersion) --force"
        case .volta:
            return "volta install \(name)@\(previousVersion)"
        case .cargo:
            return "cargo install \(name) --version \(previousVersion) --force"
        case .appStore:
            return nil
        }
    }
}
