import XCTest
@testable import MacDeck

final class TopologyAutoSwitchTests: XCTestCase {
    func testLegacyFingerprintSelfHealing() {
        let display1 = DisplayInfo(
            id: 1,
            uuid: "UUID-MAC-RETINA",
            name: "Built-in Retina",
            isMain: true,
            boundsWidth: 2056,
            boundsHeight: 1329,
            originX: 0,
            originY: 0
        )
        let display2 = DisplayInfo(
            id: 2,
            uuid: "UUID-DELL-MONITOR",
            name: "DELL Monitor",
            isMain: false,
            boundsWidth: 1920,
            boundsHeight: 1080,
            originX: 0,
            originY: -1080
        )

        let profile = WorkspaceProfile(
            name: "Office Dual-Display",
            topologyFingerprint: "legacy_v1_topology",
            displays: [display1, display2],
            items: []
        )

        var config = LayoutConfig(
            version: 2,
            activeProfileId: profile.id,
            autoQuitAfterRestore: false,
            autoRestoreOnProfileMatch: true,
            profiles: [profile]
        )

        let modified = config.healTopologyFingerprints()
        XCTAssertTrue(modified, "Should return true indicating legacy fingerprint was healed")

        let expectedFingerprint = DisplayManager.computeTopologyFingerprint(displays: [display1, display2])
        XCTAssertEqual(config.profiles.first?.topologyFingerprint, expectedFingerprint)
        XCTAssertNotEqual(config.profiles.first?.topologyFingerprint, "legacy_v1_topology")
    }

    func testV1MigrationComputesRealFingerprint() {
        let v1JSON = """
        {
            "version": 1,
            "autoQuitAfterRestore": false,
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
            "items": []
        }
        """.data(using: .utf8)!

        let config = LayoutConfig.migrateIfNecessary(from: v1JSON)
        XCTAssertNotEqual(config.profiles.first?.topologyFingerprint, "legacy_v1_topology")
        XCTAssertFalse(config.profiles.first?.topologyFingerprint.isEmpty ?? true)
    }
}
