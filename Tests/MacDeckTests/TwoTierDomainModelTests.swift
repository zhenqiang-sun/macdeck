import XCTest
@testable import MacDeck

final class TwoTierDomainModelTests: XCTestCase {
    func testDisplayTopologyInitializationAndEncoding() throws {
        let display = DisplayInfo(
            id: 1,
            uuid: "UUID-1",
            name: "Mi Monitor",
            alias: "带鱼",
            isMain: true,
            boundsWidth: 3440,
            boundsHeight: 1440,
            originX: 0,
            originY: 0
        )
        let topology = DisplayTopology(
            name: "Office Quad-Display",
            topologyFingerprint: "fingerprint_123",
            displays: [display]
        )
        
        XCTAssertEqual(topology.name, "Office Quad-Display")
        XCTAssertEqual(topology.topologyFingerprint, "fingerprint_123")
        XCTAssertEqual(topology.displays.count, 1)
        XCTAssertEqual(topology.displays.first?.alias, "带鱼")

        let data = try JSONEncoder().encode(topology)
        let decoded = try JSONDecoder().decode(DisplayTopology.self, from: data)
        XCTAssertEqual(decoded.id, topology.id)
        XCTAssertEqual(decoded.name, "Office Quad-Display")
    }

    func testWindowPresetInitializationAndEncoding() throws {
        let topoId = UUID()
        let item = WindowLayoutItem(
            bundleIdentifier: "com.apple.dt.Xcode",
            appName: "Xcode",
            targetDisplayWidth: 3440,
            targetDisplayHeight: 1440,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 100, height: 100)
        )
        let preset = WindowPreset(
            topologyId: topoId,
            name: "开发模式",
            isDefault: true,
            items: [item]
        )

        XCTAssertEqual(preset.topologyId, topoId)
        XCTAssertEqual(preset.name, "开发模式")
        XCTAssertTrue(preset.isDefault)
        XCTAssertEqual(preset.items.count, 1)

        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(WindowPreset.self, from: data)
        XCTAssertEqual(decoded.id, preset.id)
        XCTAssertEqual(decoded.topologyId, topoId)
    }
}
