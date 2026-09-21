import XCTest
@testable import MacDeck

@MainActor
final class AppStateTwoTierTests: XCTestCase {
    private var tempDir: URL!
    private var store: LayoutStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = LayoutStore(storageDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testInitialStateWithV3Config() {
        let display = DisplayInfo(
            id: 1,
            uuid: "DISP-1",
            name: "Test Display",
            alias: "带鱼",
            isMain: true,
            boundsWidth: 3440,
            boundsHeight: 1440,
            originX: 0,
            originY: 0
        )
        let topo = DisplayTopology(
            name: "Office Quad-Display",
            topologyFingerprint: "topo_hash_1",
            displays: [display]
        )
        let preset1 = WindowPreset(
            topologyId: topo.id,
            name: "开发模式",
            isDefault: true,
            items: []
        )
        let preset2 = WindowPreset(
            topologyId: topo.id,
            name: "娱乐模式",
            isDefault: false,
            items: []
        )
        let config = LayoutConfig(
            version: 3,
            activeTopologyId: topo.id,
            activePresetIdMap: [topo.id: preset1.id],
            autoQuitAfterRestore: true,
            autoRestoreOnProfileMatch: false,
            topologies: [topo],
            presets: [preset1, preset2]
        )
        store.save(config: config)

        let state = AppState(store: store)
        XCTAssertEqual(state.topologies.count, 1)
        XCTAssertEqual(state.topologies.first?.name, "Office Quad-Display")
        XCTAssertEqual(state.activeTopology?.name, "Office Quad-Display")
        XCTAssertEqual(state.presetsForActiveTopology.count, 2)
        XCTAssertEqual(state.activePreset?.name, "开发模式")
    }

    func testSwitchPresetAndMemory() {
        let topo = DisplayTopology(
            name: "办公双屏",
            topologyFingerprint: "topo_hash_2",
            displays: []
        )
        let preset1 = WindowPreset(topologyId: topo.id, name: "方案A", isDefault: true)
        let preset2 = WindowPreset(topologyId: topo.id, name: "方案B", isDefault: false)
        let config = LayoutConfig(
            version: 3,
            activeTopologyId: topo.id,
            activePresetIdMap: [topo.id: preset1.id],
            topologies: [topo],
            presets: [preset1, preset2]
        )
        store.save(config: config)

        let state = AppState(store: store)
        XCTAssertEqual(state.activePreset?.id, preset1.id)

        state.switchPreset(id: preset2.id)
        XCTAssertEqual(state.activePreset?.id, preset2.id)
        XCTAssertEqual(state.activePresetIdMap[topo.id], preset2.id)

        // 重新从 store 加载验证记忆持久化
        let reloadedConfig = store.load()
        XCTAssertEqual(reloadedConfig.activePresetIdMap[topo.id], preset2.id)
    }

    func testAliasUpdateCascadesToAllPresetsInTopology() {
        let display = DisplayInfo(
            id: 1,
            uuid: "SCREEN-DELL",
            name: "DELL U2720Q",
            alias: "旧别名",
            isMain: false,
            boundsWidth: 1920,
            boundsHeight: 1080,
            originX: 0,
            originY: 0
        )
        let topo = DisplayTopology(
            name: "Office Dual-Display",
            topologyFingerprint: "topo_hash_3",
            displays: [display]
        )
        let item1 = WindowLayoutItem(
            bundleIdentifier: "com.apple.Terminal",
            appName: "Terminal",
            targetDisplayUUID: "SCREEN-DELL",
            targetDisplayAlias: "旧别名",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 50, height: 50)
        )
        let item2 = WindowLayoutItem(
            bundleIdentifier: "com.apple.Notes",
            appName: "Notes",
            targetDisplayUUID: "SCREEN-DELL",
            targetDisplayAlias: "旧别名",
            targetDisplayWidth: 1920,
            targetDisplayHeight: 1080,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 10, y: 10, width: 40, height: 40)
        )
        let preset1 = WindowPreset(topologyId: topo.id, name: "预设1", isDefault: true, items: [item1])
        let preset2 = WindowPreset(topologyId: topo.id, name: "预设2", isDefault: false, items: [item2])

        let config = LayoutConfig(
            version: 3,
            activeTopologyId: topo.id,
            activePresetIdMap: [topo.id: preset1.id],
            topologies: [topo],
            presets: [preset1, preset2]
        )
        store.save(config: config)

        let state = AppState(store: store)
        state.updateDisplayAlias(displayUUID: "SCREEN-DELL", alias: "新竖屏别名")

        // 验证拓扑中的别名
        XCTAssertEqual(state.activeTopology?.displays.first?.alias, "新竖屏别名")

        // 验证所有方案中的 targetDisplayAlias 被级联修改
        let loaded = store.load()
        let p1 = loaded.presets.first(where: { $0.id == preset1.id })
        let p2 = loaded.presets.first(where: { $0.id == preset2.id })
        XCTAssertEqual(p1?.items.first?.targetDisplayAlias, "新竖屏别名")
        XCTAssertEqual(p2?.items.first?.targetDisplayAlias, "新竖屏别名")
    }
}
