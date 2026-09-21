import Foundation

public struct DisplayTopology: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var topologyFingerprint: String
    public var displays: [DisplayInfo]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        topologyFingerprint: String,
        displays: [DisplayInfo] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.topologyFingerprint = topologyFingerprint
        self.displays = displays
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case topologyFingerprint
        case displays
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.topologyFingerprint = try container.decodeIfPresent(String.self, forKey: .topologyFingerprint) ?? ""
        self.displays = try container.decodeIfPresent([DisplayInfo].self, forKey: .displays) ?? []
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}
