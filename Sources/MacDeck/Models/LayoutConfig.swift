import Foundation

public struct LayoutConfig: Codable, Equatable {
    public var version: Int
    public var activeTopologyId: UUID?
    public var activePresetIdMap: [UUID: UUID]
    public var autoQuitAfterRestore: Bool
    public var autoRestoreOnProfileMatch: Bool
    public var displayAliases: [String: String]
    public var topologies: [DisplayTopology]
    public var presets: [WindowPreset]

    public init(
        version: Int = 3,
        activeTopologyId: UUID? = nil,
        activePresetIdMap: [UUID: UUID] = [:],
        autoQuitAfterRestore: Bool = false,
        autoRestoreOnProfileMatch: Bool = false,
        displayAliases: [String: String] = [:],
        topologies: [DisplayTopology] = [],
        presets: [WindowPreset] = []
    ) {
        self.version = version
        self.activeTopologyId = activeTopologyId ?? topologies.first?.id
        self.activePresetIdMap = activePresetIdMap
        self.autoQuitAfterRestore = autoQuitAfterRestore
        self.autoRestoreOnProfileMatch = autoRestoreOnProfileMatch
        self.displayAliases = displayAliases
        self.topologies = topologies
        self.presets = presets
    }

    enum CodingKeys: String, CodingKey {
        case version
        case activeTopologyId
        case activePresetIdMap
        case autoQuitAfterRestore
        case autoRestoreOnProfileMatch
        case displayAliases
        case topologies
        case presets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 3
        self.activeTopologyId = try container.decodeIfPresent(UUID.self, forKey: .activeTopologyId)
        self.activePresetIdMap = try container.decodeIfPresent([UUID: UUID].self, forKey: .activePresetIdMap) ?? [:]
        self.autoQuitAfterRestore = try container.decodeIfPresent(Bool.self, forKey: .autoQuitAfterRestore) ?? false
        self.autoRestoreOnProfileMatch = try container.decodeIfPresent(Bool.self, forKey: .autoRestoreOnProfileMatch) ?? false
        var aliases = try container.decodeIfPresent([String: String].self, forKey: .displayAliases) ?? [:]
        var topos = try container.decodeIfPresent([DisplayTopology].self, forKey: .topologies) ?? []
        let psets = try container.decodeIfPresent([WindowPreset].self, forKey: .presets) ?? []

        // 自动从 topologies 收集已存别名
        for t in topos {
            for d in t.displays {
                if let a = d.alias, !a.trimmingCharacters(in: .whitespaces).isEmpty {
                    if aliases[d.uuid] == nil {
                        aliases[d.uuid] = a
                    }
                }
            }
        }
        // 自动从 presets.items 中收集已存别名（防止历史快照遗漏）
        for p in psets {
            for item in p.items {
                if let u = item.targetDisplayUUID, let a = item.targetDisplayAlias, !a.trimmingCharacters(in: .whitespaces).isEmpty {
                    if aliases[u] == nil {
                        aliases[u] = a
                    }
                }
            }
        }
        // 自动将 aliases 回填至 topos 中 alias 为空或者丢失的 displays
        for tIdx in 0..<topos.count {
            for dIdx in 0..<topos[tIdx].displays.count {
                let uuid = topos[tIdx].displays[dIdx].uuid
                if (topos[tIdx].displays[dIdx].alias == nil || topos[tIdx].displays[dIdx].alias?.isEmpty == true),
                   let savedAlias = aliases[uuid] {
                    topos[tIdx].displays[dIdx].alias = savedAlias
                }
            }
        }

        self.displayAliases = aliases
        self.topologies = topos
        self.presets = psets
    }

    public var activeTopology: DisplayTopology? {
        get {
            if let id = activeTopologyId {
                return topologies.first { $0.id == id }
            }
            return topologies.first
        }
        set {
            if let newTopo = newValue, let idx = topologies.firstIndex(where: { $0.id == newTopo.id }) {
                topologies[idx] = newTopo
            }
        }
    }

    public var activePreset: WindowPreset? {
        get {
            guard let topo = activeTopology else { return presets.first }
            if let presetId = activePresetIdMap[topo.id] {
                if let found = presets.first(where: { $0.id == presetId && $0.topologyId == topo.id }) {
                    return found
                }
            }
            return presets.first(where: { $0.topologyId == topo.id && $0.isDefault })
                ?? presets.first(where: { $0.topologyId == topo.id })
                ?? presets.first
        }
        set {
            if let newPreset = newValue, let idx = presets.firstIndex(where: { $0.id == newPreset.id }) {
                presets[idx] = newPreset
            }
        }
    }

    // MARK: - Backward Compatibility Bridges
    public var activeProfileId: UUID? {
        get { activePreset?.id }
        set {
            if let newId = newValue, let targetPreset = presets.first(where: { $0.id == newId }) {
                activeTopologyId = targetPreset.topologyId
                activePresetIdMap[targetPreset.topologyId] = targetPreset.id
            }
        }
    }

    public var activeProfile: WorkspaceProfile? {
        get {
            guard let topo = activeTopology, let preset = activePreset else { return nil }
            return WorkspaceProfile(
                id: preset.id,
                name: preset.name == "默认方案" ? topo.name : "\(topo.name)-\(preset.name)",
                topologyFingerprint: topo.topologyFingerprint,
                displays: topo.displays,
                items: preset.items,
                createdAt: preset.createdAt,
                updatedAt: preset.updatedAt
            )
        }
        set {
            guard let profile = newValue else { return }
            if let topoIdx = topologies.firstIndex(where: { $0.topologyFingerprint == profile.topologyFingerprint }) {
                topologies[topoIdx].displays = profile.displays
                if let presetIdx = presets.firstIndex(where: { $0.id == profile.id }) {
                    presets[presetIdx].items = profile.items
                }
            }
        }
    }

    public var profiles: [WorkspaceProfile] {
        get {
            var list: [WorkspaceProfile] = []
            for topo in topologies {
                let topoPresets = presets.filter { $0.topologyId == topo.id }
                if topoPresets.isEmpty {
                    list.append(WorkspaceProfile(
                        id: topo.id,
                        name: topo.name,
                        topologyFingerprint: topo.topologyFingerprint,
                        displays: topo.displays,
                        items: []
                    ))
                } else {
                    for preset in topoPresets {
                        let name = (topoPresets.count > 1 && preset.name != "默认方案")
                            ? "\(topo.name)-\(preset.name)"
                            : topo.name
                        list.append(WorkspaceProfile(
                            id: preset.id,
                            name: name,
                            topologyFingerprint: topo.topologyFingerprint,
                            displays: topo.displays,
                            items: preset.items,
                            createdAt: preset.createdAt,
                            updatedAt: preset.updatedAt
                        ))
                    }
                }
            }
            return list
        }
        set {
            // Bridge assignment
        }
    }

    public var displays: [DisplayInfo] {
        get { activeTopology?.displays ?? topologies.first?.displays ?? [] }
        set {
            if let id = activeTopologyId, let idx = topologies.firstIndex(where: { $0.id == id }) {
                topologies[idx].displays = newValue
            } else if !topologies.isEmpty {
                topologies[0].displays = newValue
            }
        }
    }

    public var items: [WindowLayoutItem] {
        get { activePreset?.items ?? presets.first?.items ?? [] }
        set {
            if let activeP = activePreset, let idx = presets.firstIndex(where: { $0.id == activeP.id }) {
                presets[idx].items = newValue
            } else if !presets.isEmpty {
                presets[0].items = newValue
            }
        }
    }

    public init(
        version: Int = 3,
        activeProfileId: UUID? = nil,
        autoQuitAfterRestore: Bool = false,
        autoRestoreOnProfileMatch: Bool = false,
        profiles: [WorkspaceProfile] = []
    ) {
        let v2Config = LayoutConfig.migrateV2Profiles(
            profiles: profiles,
            activeProfileId: activeProfileId,
            autoQuit: autoQuitAfterRestore,
            autoRestore: autoRestoreOnProfileMatch
        )
        self = v2Config
    }

    public init(
        version: Int = 3,
        autoQuitAfterRestore: Bool = false,
        displays: [DisplayInfo] = [],
        items: [WindowLayoutItem] = []
    ) {
        let fingerprint = displays.isEmpty ? "default_topology" : DisplayManager.computeTopologyFingerprint(displays: displays)
        let defaultTopo = DisplayTopology(
            name: "默认工作环境",
            topologyFingerprint: fingerprint,
            displays: displays
        )
        let defaultPreset = WindowPreset(
            topologyId: defaultTopo.id,
            name: "默认方案",
            isDefault: true,
            items: items
        )
        self.version = 3
        self.activeTopologyId = defaultTopo.id
        self.activePresetIdMap = [defaultTopo.id: defaultPreset.id]
        self.autoQuitAfterRestore = autoQuitAfterRestore
        self.autoRestoreOnProfileMatch = false
        var aliases: [String: String] = [:]
        for d in displays {
            if let a = d.alias, !a.isEmpty {
                aliases[d.uuid] = a
            }
        }
        for item in items {
            if let u = item.targetDisplayUUID, let a = item.targetDisplayAlias, !a.isEmpty {
                aliases[u] = a
            }
        }
        self.displayAliases = aliases
        self.topologies = [defaultTopo]
        self.presets = [defaultPreset]
    }

    @discardableResult
    public mutating func healTopologyFingerprints() -> Bool {
        var modified = false
        for i in 0..<topologies.count {
            if topologies[i].topologyFingerprint == "legacy_v1_topology" ||
               topologies[i].topologyFingerprint.trimmingCharacters(in: .whitespaces).isEmpty {
                if !topologies[i].displays.isEmpty {
                    topologies[i].topologyFingerprint = DisplayManager.computeTopologyFingerprint(displays: topologies[i].displays)
                    modified = true
                }
            }
            // 确保每个 topology 的 displays 中同步持久化别名
            for dIdx in 0..<topologies[i].displays.count {
                let uuid = topologies[i].displays[dIdx].uuid
                if (topologies[i].displays[dIdx].alias == nil || topologies[i].displays[dIdx].alias?.isEmpty == true),
                   let savedAlias = displayAliases[uuid] {
                    topologies[i].displays[dIdx].alias = savedAlias
                    modified = true
                }
            }
        }
        return modified
    }

    public static func migrateV2Profiles(
        profiles: [WorkspaceProfile],
        activeProfileId: UUID?,
        autoQuit: Bool,
        autoRestore: Bool
    ) -> LayoutConfig {
        var topologies: [DisplayTopology] = []
        var presets: [WindowPreset] = []
        var presetMap: [UUID: UUID] = [:]
        var activeTopoId: UUID? = nil

        var seenFingerprints: [String] = []
        var groups: [String: [WorkspaceProfile]] = [:]
        for p in profiles {
            let fp = p.topologyFingerprint.isEmpty ? DisplayManager.computeTopologyFingerprint(displays: p.displays) : p.topologyFingerprint
            if groups[fp] == nil {
                seenFingerprints.append(fp)
                groups[fp] = []
            }
            groups[fp]?.append(p)
        }

        for fp in seenFingerprints {
            guard let group = groups[fp], let firstP = group.first else { continue }
            
            var mergedDisplays: [DisplayInfo] = firstP.displays
            for p in group.dropFirst() {
                for d in p.displays {
                    if let idx = mergedDisplays.firstIndex(where: { $0.uuid == d.uuid }) {
                        if (mergedDisplays[idx].alias == nil || mergedDisplays[idx].alias?.isEmpty == true),
                           let newAlias = d.alias, !newAlias.isEmpty {
                            mergedDisplays[idx].alias = newAlias
                        }
                    } else {
                        mergedDisplays.append(d)
                    }
                }
            }

            let topoName = firstP.name
            let topology = DisplayTopology(
                name: topoName,
                topologyFingerprint: fp,
                displays: mergedDisplays,
                createdAt: firstP.createdAt,
                updatedAt: firstP.updatedAt
            )
            topologies.append(topology)

            for (index, p) in group.enumerated() {
                var presetName = p.name
                if presetName == topoName {
                    presetName = "默认方案"
                } else if presetName.hasPrefix("\(topoName)-") {
                    presetName = String(presetName.dropFirst("\(topoName)-".count))
                } else if presetName.hasPrefix("\(topoName) - ") {
                    presetName = String(presetName.dropFirst("\(topoName) - ".count))
                }

                let preset = WindowPreset(
                    id: p.id,
                    topologyId: topology.id,
                    name: presetName,
                    isDefault: (index == 0),
                    items: p.items,
                    createdAt: p.createdAt,
                    updatedAt: p.updatedAt
                )
                presets.append(preset)

                if let activeId = activeProfileId, p.id == activeId {
                    activeTopoId = topology.id
                    presetMap[topology.id] = preset.id
                } else if presetMap[topology.id] == nil {
                    presetMap[topology.id] = preset.id
                }
            }
        }

        if activeTopoId == nil {
            activeTopoId = topologies.first?.id
        }

        var collectedAliases: [String: String] = [:]
        for t in topologies {
            for d in t.displays {
                if let a = d.alias, !a.isEmpty {
                    collectedAliases[d.uuid] = a
                }
            }
        }
        for p in presets {
            for item in p.items {
                if let u = item.targetDisplayUUID, let a = item.targetDisplayAlias, !a.isEmpty {
                    if collectedAliases[u] == nil {
                        collectedAliases[u] = a
                    }
                }
            }
        }

        return LayoutConfig(
            version: 3,
            activeTopologyId: activeTopoId,
            activePresetIdMap: presetMap,
            autoQuitAfterRestore: autoQuit,
            autoRestoreOnProfileMatch: autoRestore,
            displayAliases: collectedAliases,
            topologies: topologies,
            presets: presets
        )
    }

    public static func migrateIfNecessary(from data: Data) -> LayoutConfig {
        let decoder = JSONDecoder()

        if let v3 = try? decoder.decode(LayoutConfig.self, from: data), v3.version >= 3 {
            var healed = v3
            _ = healed.healTopologyFingerprints()
            return healed
        }

        struct V2Config: Codable {
            var version: Int?
            var activeProfileId: UUID?
            var autoQuitAfterRestore: Bool?
            var autoRestoreOnProfileMatch: Bool?
            var profiles: [WorkspaceProfile]?
        }

        if let v2 = try? decoder.decode(V2Config.self, from: data), let profiles = v2.profiles, !profiles.isEmpty {
            var migrated = migrateV2Profiles(
                profiles: profiles,
                activeProfileId: v2.activeProfileId,
                autoQuit: v2.autoQuitAfterRestore ?? false,
                autoRestore: v2.autoRestoreOnProfileMatch ?? false
            )
            _ = migrated.healTopologyFingerprints()
            return migrated
        }

        struct V1Config: Codable {
            var version: Int?
            var autoQuitAfterRestore: Bool?
            var displays: [DisplayInfo]?
            var items: [WindowLayoutItem]?
        }

        if let v1 = try? decoder.decode(V1Config.self, from: data) {
            let displays = v1.displays ?? []
            let fingerprint = displays.isEmpty ? "legacy_v1_topology" : DisplayManager.computeTopologyFingerprint(displays: displays)
            let defaultTopo = DisplayTopology(
                name: "默认工作环境",
                topologyFingerprint: fingerprint,
                displays: displays
            )
            let defaultPreset = WindowPreset(
                topologyId: defaultTopo.id,
                name: "默认方案",
                isDefault: true,
                items: v1.items ?? []
            )
            var config = LayoutConfig(
                version: 3,
                activeTopologyId: defaultTopo.id,
                activePresetIdMap: [defaultTopo.id: defaultPreset.id],
                autoQuitAfterRestore: v1.autoQuitAfterRestore ?? true,
                autoRestoreOnProfileMatch: false,
                topologies: [defaultTopo],
                presets: [defaultPreset]
            )
            _ = config.healTopologyFingerprints()
            return config
        }

        return LayoutConfig()
    }
}
