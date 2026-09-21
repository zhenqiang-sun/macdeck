import Foundation

public struct DisplayInfo: Codable, Identifiable, Equatable {
    public var id: UInt32
    public var uuid: String
    public var name: String
    public var alias: String?
    public var isMain: Bool
    public var boundsWidth: Double
    public var boundsHeight: Double
    public var originX: Double
    public var originY: Double

    public var displayName: String {
        if let alias = alias, !alias.trimmingCharacters(in: .whitespaces).isEmpty {
            return alias
        }
        return name
    }

    public init(
        id: UInt32,
        uuid: String = "",
        name: String,
        alias: String? = nil,
        isMain: Bool,
        boundsWidth: Double,
        boundsHeight: Double,
        originX: Double,
        originY: Double
    ) {
        self.id = id
        self.uuid = uuid.isEmpty ? "DISPLAY-\(id)" : uuid
        self.name = name
        self.alias = alias
        self.isMain = isMain
        self.boundsWidth = boundsWidth
        self.boundsHeight = boundsHeight
        self.originX = originX
        self.originY = originY
    }

    enum CodingKeys: String, CodingKey {
        case id, uuid, name, alias, isMain, boundsWidth, boundsHeight, originX, originY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UInt32.self, forKey: .id)
        self.uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? "DISPLAY-\(self.id)"
        self.name = try container.decode(String.self, forKey: .name)
        self.alias = try container.decodeIfPresent(String.self, forKey: .alias)
        self.isMain = try container.decode(Bool.self, forKey: .isMain)
        self.boundsWidth = try container.decode(Double.self, forKey: .boundsWidth)
        self.boundsHeight = try container.decode(Double.self, forKey: .boundsHeight)
        self.originX = try container.decode(Double.self, forKey: .originX)
        self.originY = try container.decode(Double.self, forKey: .originY)
    }
}
