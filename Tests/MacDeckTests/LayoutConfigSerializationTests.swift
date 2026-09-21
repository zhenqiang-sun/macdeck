import XCTest
@testable import MacDeck

final class LayoutConfigSerializationTests: XCTestCase {
    func testV3ConfigSerialization() throws {
        let display = DisplayInfo(
            id: 1,
            uuid: "SCREEN-UUID-1234",
            name: "DELL U2720Q",
            alias: "左侧竖屏",
            isMain: false,
            boundsWidth: 1920,
            boundsHeight: 1080,
            originX: -1920,
            originY: 0
        )
        let topology = DisplayTopology(
            name: "公司工位",
            topologyFingerprint: "hash_test_123",
            displays: [display]
        )
        let item = WindowLayoutItem(
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari",
            targetDisplayUUID: "SCREEN-UUID-1234",
            targetDisplayAlias: "左侧竖屏",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 10, y: 10, width: 800, height: 600)
        )
        let preset = WindowPreset(
            topologyId: topology.id,
            name: "默认方案",
            isDefault: true,
            items: [item]
        )
        let config = LayoutConfig(
            version: 3,
            activeTopologyId: topology.id,
            activePresetIdMap: [topology.id: preset.id],
            autoQuitAfterRestore: true,
            autoRestoreOnProfileMatch: false,
            topologies: [topology],
            presets: [preset]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LayoutConfig.self, from: data)

        XCTAssertEqual(decoded.version, 3)
        XCTAssertEqual(decoded.topologies.count, 1)
        XCTAssertEqual(decoded.topologies.first?.name, "公司工位")
        XCTAssertEqual(decoded.topologies.first?.displays.first?.alias, "左侧竖屏")
        XCTAssertEqual(decoded.topologies.first?.displays.first?.uuid, "SCREEN-UUID-1234")
        XCTAssertEqual(decoded.presets.count, 1)
        XCTAssertEqual(decoded.presets.first?.name, "默认方案")
        XCTAssertEqual(decoded.presets.first?.topologyId, topology.id)
        XCTAssertEqual(decoded.presets.first?.items.first?.targetDisplayUUID, "SCREEN-UUID-1234")
    }

    func testV2ToV3MigrationDecoding() throws {
        let v2JSON = """
        {
            "version": 2,
            "activeProfileId": "091A837C-D0D0-4A46-878B-4928E7865200",
            "autoQuitAfterRestore": true,
            "autoRestoreOnProfileMatch": true,
            "profiles": [
                {
                    "id": "11111111-1111-1111-1111-111111111111",
                    "name": "Office Dual-Display",
                    "topologyFingerprint": "fingerprint_dual",
                    "displays": [
                        {
                            "id": 1,
                            "uuid": "UUID-MAIN",
                            "name": "Retina Display",
                            "alias": "主屏",
                            "isMain": true,
                            "boundsWidth": 2056,
                            "boundsHeight": 1329,
                            "originX": 0,
                            "originY": 0
                        }
                    ],
                    "items": [
                        {
                            "bundleIdentifier": "com.apple.Terminal",
                            "appName": "Terminal",
                            "targetDisplayUUID": "UUID-MAIN",
                            "targetDisplayWidth": 2056,
                            "targetDisplayHeight": 1329,
                            "targetDisplayIsMain": true,
                            "relativeFrame": { "x": 0, "y": 0, "width": 800, "height": 600 },
                            "isRecorded": true
                        }
                    ]
                },
                {
                    "id": "091A837C-D0D0-4A46-878B-4928E7865200",
                    "name": "Office Quad-Display",
                    "topologyFingerprint": "fingerprint_quad",
                    "displays": [
                        {
                            "id": 1,
                            "uuid": "UUID-MAIN",
                            "name": "Retina Display",
                            "alias": "内屏",
                            "isMain": true,
                            "boundsWidth": 2056,
                            "boundsHeight": 1329,
                            "originX": 0,
                            "originY": 0
                        },
                        {
                            "id": 2,
                            "uuid": "UUID-ULTRAWIDE",
                            "name": "Mi Monitor",
                            "alias": "带鱼",
                            "isMain": false,
                            "boundsWidth": 3440,
                            "boundsHeight": 1440,
                            "originX": 2056,
                            "originY": 0
                        }
                    ],
                    "items": [
                        {
                            "bundleIdentifier": "com.openai.codex",
                            "appName": "ChatGPT",
                            "targetDisplayUUID": "UUID-ULTRAWIDE",
                            "targetDisplayAlias": "带鱼",
                            "targetDisplayWidth": 3440,
                            "targetDisplayHeight": 1440,
                            "targetDisplayIsMain": false,
                            "relativeFrame": { "x": 50, "y": 50, "width": 1000, "height": 800 },
                            "isRecorded": true
                        }
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let config = LayoutConfig.migrateIfNecessary(from: v2JSON)
        XCTAssertEqual(config.version, 3)
        XCTAssertEqual(config.topologies.count, 2)
        
        let quadTopology = config.topologies.first { $0.topologyFingerprint == "fingerprint_quad" }
        XCTAssertNotNil(quadTopology)
        XCTAssertEqual(quadTopology?.name, "Office Quad-Display")
        XCTAssertEqual(quadTopology?.displays.count, 2)
        XCTAssertEqual(quadTopology?.displays.first(where: { $0.uuid == "UUID-ULTRAWIDE" })?.alias, "带鱼")

        let quadPreset = config.presets.first { $0.topologyId == quadTopology?.id }
        XCTAssertNotNil(quadPreset)
        XCTAssertEqual(quadPreset?.items.count, 1)
        XCTAssertEqual(quadPreset?.items.first?.appName, "ChatGPT")
        XCTAssertEqual(quadPreset?.items.first?.targetDisplayAlias, "带鱼")

        XCTAssertEqual(config.activeTopologyId, quadTopology?.id)
        XCTAssertEqual(config.autoQuitAfterRestore, true)
        XCTAssertEqual(config.autoRestoreOnProfileMatch, true)
    }

    func testV1ToV3MigrationDecoding() throws {
        let v1JSON = """
        {
            "version": 1,
            "autoQuitAfterRestore": true,
            "displays": [
                {
                    "id": 1,
                    "uuid": "SCREEN-1",
                    "name": "Built-in Display",
                    "isMain": true,
                    "boundsWidth": 1512,
                    "boundsHeight": 982,
                    "originX": 0,
                    "originY": 0
                }
            ],
            "items": [
                {
                    "bundleIdentifier": "com.apple.Terminal",
                    "appName": "Terminal",
                    "targetDisplayUUID": "SCREEN-1",
                    "targetDisplayWidth": 1512,
                    "targetDisplayHeight": 982,
                    "targetDisplayIsMain": true,
                    "relativeFrame": { "x": 0, "y": 0, "width": 800, "height": 600 },
                    "isRecorded": true
                }
            ]
        }
        """.data(using: .utf8)!

        let config = LayoutConfig.migrateIfNecessary(from: v1JSON)
        XCTAssertEqual(config.version, 3)
        XCTAssertEqual(config.topologies.count, 1)
        XCTAssertEqual(config.presets.count, 1)
        XCTAssertEqual(config.presets.first?.items.count, 1)
        XCTAssertEqual(config.presets.first?.items.first?.appName, "Terminal")
        XCTAssertEqual(config.topologies.first?.displays.first?.name, "Built-in Display")
    }
}
