import Foundation

public struct WindowPreset: Codable, Identifiable, Equatable {
    public var id: UUID
    public var topologyId: UUID
    public var name: String
    public var isDefault: Bool
    public var items: [WindowLayoutItem]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        topologyId: UUID,
        name: String,
        isDefault: Bool = false,
        items: [WindowLayoutItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.topologyId = topologyId
        self.name = name
        self.isDefault = isDefault
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case topologyId
        case name
        case isDefault
        case items
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.topologyId = try container.decodeIfPresent(UUID.self, forKey: .topologyId) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        self.items = try container.decodeIfPresent([WindowLayoutItem].self, forKey: .items) ?? []
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}
