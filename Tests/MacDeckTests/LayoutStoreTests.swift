import XCTest
@testable import MacDeck

final class LayoutStoreTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testSaveAndLoadConfig() {
        let store = LayoutStore(storageDirectory: tempDirectory)
        var config = LayoutConfig()
        config.autoQuitAfterRestore = false
        config.items = [
            WindowLayoutItem(
                bundleIdentifier: "com.apple.Terminal",
                appName: "Terminal",
                profile: nil,
                targetDisplayWidth: 1920,
                targetDisplayHeight: 1080,
                targetDisplayIsMain: true,
                relativeFrame: RelativeRect(x: 10, y: 10, width: 800, height: 600)
            )
        ]

        store.save(config: config)
        let loaded = store.load()

        XCTAssertEqual(loaded.autoQuitAfterRestore, false)
        XCTAssertEqual(loaded.items.count, 1)
        XCTAssertEqual(loaded.items.first?.appName, "Terminal")
    }

    func testLegacyConfigMigration() throws {
        let legacyJSON = """
        {
            "version": 2,
            "autoQuitAfterRestore": true,
            "profiles": [
                {
                    "id": "11111111-1111-1111-1111-111111111111",
                    "name": "Office Dual-Display",
                    "topologyFingerprint": "fingerprint_dual",
                    "displays": [],
                    "items": []
                }
            ]
        }
        """
        let data = legacyJSON.data(using: .utf8)!
        let migrated = LayoutConfig.migrateIfNecessary(from: data)
        XCTAssertEqual(migrated.version, 3)
        XCTAssertEqual(migrated.autoQuitAfterRestore, true)
        XCTAssertEqual(migrated.topologies.count, 1)
        XCTAssertEqual(migrated.topologies.first?.name, "Office Dual-Display")
    }
}
