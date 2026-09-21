import Foundation

public enum HealthStatus: String, Codable, Equatable {
    case healthy = "健康"
    case warning = "警告"
    case error = "异常"
    case notInstalled = "未安装"

    public var iconName: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .notInstalled: return "minus.circle.fill"
        }
    }
}

public struct DoctorItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public var status: HealthStatus
    public var summary: String
    public var details: [String]
    public var fixCommand: String?

    public init(
        id: String,
        title: String,
        subtitle: String,
        status: HealthStatus,
        summary: String,
        details: [String] = [],
        fixCommand: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.summary = summary
        self.details = details
        self.fixCommand = fixCommand
    }
}
