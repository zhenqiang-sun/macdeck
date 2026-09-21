import Foundation

public struct RelativeRect: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct WindowLayoutItem: Codable, Identifiable, Equatable {
    public var id: String { "\(bundleIdentifier):\(profile ?? "default"):\(windowIndex)" }
    public var bundleIdentifier: String
    public var appName: String
    public var profile: String?
    public var windowIndex: Int
    public var windowTitle: String?
    public var targetDisplayUUID: String?
    public var targetDisplayAlias: String?
    public var targetDisplayWidth: Double
    public var targetDisplayHeight: Double
    public var targetDisplayIsMain: Bool
    public var relativeFrame: RelativeRect
    public var isRecorded: Bool
    public var isFullScreen: Bool?
    public var isMinimized: Bool?

    public init(
        bundleIdentifier: String,
        appName: String,
        profile: String? = nil,
        windowIndex: Int = 0,
        windowTitle: String? = nil,
        targetDisplayUUID: String? = nil,
        targetDisplayAlias: String? = nil,
        targetDisplayWidth: Double,
        targetDisplayHeight: Double,
        targetDisplayIsMain: Bool,
        relativeFrame: RelativeRect,
        isRecorded: Bool = true,
        isFullScreen: Bool? = nil,
        isMinimized: Bool? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.profile = profile
        self.windowIndex = windowIndex
        self.windowTitle = windowTitle
        self.targetDisplayUUID = targetDisplayUUID
        self.targetDisplayAlias = targetDisplayAlias
        self.targetDisplayWidth = targetDisplayWidth
        self.targetDisplayHeight = targetDisplayHeight
        self.targetDisplayIsMain = targetDisplayIsMain
        self.relativeFrame = relativeFrame
        self.isRecorded = isRecorded
        self.isFullScreen = isFullScreen
        self.isMinimized = isMinimized
    }

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case appName
        case profile
        case windowIndex
        case windowTitle
        case targetDisplayUUID
        case targetDisplayAlias
        case targetDisplayWidth
        case targetDisplayHeight
        case targetDisplayIsMain
        case relativeFrame
        case isRecorded
        case isFullScreen
        case isMinimized
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        self.appName = try container.decode(String.self, forKey: .appName)
        self.profile = try container.decodeIfPresent(String.self, forKey: .profile)
        self.windowIndex = try container.decodeIfPresent(Int.self, forKey: .windowIndex) ?? 0
        self.windowTitle = try container.decodeIfPresent(String.self, forKey: .windowTitle)
        self.targetDisplayUUID = try container.decodeIfPresent(String.self, forKey: .targetDisplayUUID)
        self.targetDisplayAlias = try container.decodeIfPresent(String.self, forKey: .targetDisplayAlias)
        self.targetDisplayWidth = try container.decode(Double.self, forKey: .targetDisplayWidth)
        self.targetDisplayHeight = try container.decode(Double.self, forKey: .targetDisplayHeight)
        self.targetDisplayIsMain = try container.decode(Bool.self, forKey: .targetDisplayIsMain)
        self.relativeFrame = try container.decode(RelativeRect.self, forKey: .relativeFrame)
        self.isRecorded = try container.decodeIfPresent(Bool.self, forKey: .isRecorded) ?? true
        self.isFullScreen = try container.decodeIfPresent(Bool.self, forKey: .isFullScreen)
        self.isMinimized = try container.decodeIfPresent(Bool.self, forKey: .isMinimized)
    }
}
