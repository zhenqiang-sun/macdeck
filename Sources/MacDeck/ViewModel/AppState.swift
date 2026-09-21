import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    @Published public var displays: [DisplayInfo] = []
    @Published public var displayedItems: [WindowLayoutItem] = []
    @Published public var autoQuitAfterRestore: Bool = false
    @Published public var autoRestoreOnProfileMatch: Bool = false
    @Published public var hasPermission: Bool = false
    @Published public var statusMessage: String? = nil
    @Published public var pendingUpdateCount: Int = 0

    // 两级领域模型状态
    @Published public var topologies: [DisplayTopology] = []
    @Published public var presets: [WindowPreset] = []
    @Published public var activeTopology: DisplayTopology? = nil
    @Published public var activePreset: WindowPreset? = nil
    @Published public var activePresetIdMap: [UUID: UUID] = [:]
    @Published public var isNewTopologyDetected: Bool = false

    // 向后兼容视图绑定的代理字段
    @Published public var profiles: [WorkspaceProfile] = []
    @Published public var activeProfile: WorkspaceProfile? = nil

    private let store: LayoutStore
    private let windowManager: WindowManager
    private let displayManager: DisplayManager

    public init(
        store: LayoutStore = .shared,
        windowManager: WindowManager = .shared,
        displayManager: DisplayManager = .shared
    ) {
        self.store = store
        self.windowManager = windowManager
        self.displayManager = displayManager

        let config = store.load()
        self.autoQuitAfterRestore = config.autoQuitAfterRestore
        self.autoRestoreOnProfileMatch = config.autoRestoreOnProfileMatch
        self.topologies = config.topologies
        self.presets = config.presets
        self.activePresetIdMap = config.activePresetIdMap

        displayManager.startObservingScreenChanges { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleScreenChange()
            }
        }

        SoftwareUpdateBackgroundChecker.shared.$pendingUpdateCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingUpdateCount)

        refresh(forceHardwareSync: true)
    }

    public func checkPermission() {
        hasPermission = WindowManager.checkAccessibilityPermission()
    }

    public var presetsForActiveTopology: [WindowPreset] {
        guard let topo = activeTopology else { return [] }
        return presets.filter { $0.topologyId == topo.id }
    }

    public var isCurrentProfileHardwareMatched: Bool {
        guard let topo = activeTopology else { return false }
        let currentFingerprint = DisplayManager.computeTopologyFingerprint(displays: displays)
        return topo.topologyFingerprint == currentFingerprint
    }

    public func alignWithCurrentHardware() {
        refresh(forceHardwareSync: true)
        if let topo = activeTopology, isCurrentProfileHardwareMatched {
            statusMessage = "已重新对齐物理屏幕环境：\(topo.name)"
        }
    }

    public func currentDisplayAliases() -> [String: String] {
        var map: [String: String] = [:]
        let config = store.load()
        // 1. 全局配置持久化别名池
        for (uuid, alias) in config.displayAliases {
            if !alias.trimmingCharacters(in: .whitespaces).isEmpty {
                map[uuid] = alias
            }
        }
        // 2. 跨所有拓扑收集别名
        for topo in config.topologies {
            for d in topo.displays {
                if let a = d.alias, !a.trimmingCharacters(in: .whitespaces).isEmpty {
                    map[d.uuid] = a
                }
            }
        }
        // 3. 预设项中的别名回退收集 (防止丢失)
        for preset in config.presets {
            for item in preset.items {
                if let u = item.targetDisplayUUID, let a = item.targetDisplayAlias, !a.trimmingCharacters(in: .whitespaces).isEmpty {
                    if map[u] == nil {
                        map[u] = a
                    }
                }
            }
        }
        // 4. 当前运行中的显示器别名覆盖
        for d in displays {
            if let a = d.alias, !a.trimmingCharacters(in: .whitespaces).isEmpty {
                map[d.uuid] = a
            }
        }
        return map
    }

    private func handleScreenChange() {
        checkPermission()
        let config = store.load()
        let currentDisplays = displayManager.getCurrentDisplays()
        let currentFingerprint = DisplayManager.computeTopologyFingerprint(displays: currentDisplays)

        if let matched = config.topologies.first(where: { $0.topologyFingerprint == currentFingerprint }) {
            let wasDifferent = activeTopology?.id != matched.id
            activeTopology = matched
            isNewTopologyDetected = false
            statusMessage = "🟢 已自动切入屏幕环境：\(matched.name)"

            refresh(forceHardwareSync: true)

            if wasDifferent && autoRestoreOnProfileMatch {
                restoreAll()
            }
        } else {
            isNewTopologyDetected = true
            statusMessage = "💡 检测到新屏幕环境 (\(currentDisplays.count) 台显示器)，可配置新环境"
            refresh(forceHardwareSync: false)
        }
    }

    public func refresh(forceHardwareSync: Bool = true) {
        checkPermission()
        var currentDisplays = displayManager.getCurrentDisplays()
        let currentFingerprint = DisplayManager.computeTopologyFingerprint(displays: currentDisplays)

        var config = store.load()
        self.topologies = config.topologies
        self.presets = config.presets
        self.activePresetIdMap = config.activePresetIdMap

        // 1. 硬件拓扑匹配与激活
        let matchedTopo = config.topologies.first(where: { $0.topologyFingerprint == currentFingerprint })
        if let matched = matchedTopo {
            self.isNewTopologyDetected = false
            if forceHardwareSync || self.activeTopology == nil {
                self.activeTopology = matched
                config.activeTopologyId = matched.id
            }
        } else {
            self.isNewTopologyDetected = true
            if self.activeTopology == nil {
                if let activeId = config.activeTopologyId, let found = config.topologies.first(where: { $0.id == activeId }) {
                    self.activeTopology = found
                } else {
                    self.activeTopology = config.topologies.first
                }
            }
        }

        // 2. 激活方案选择
        if let currentTopo = self.activeTopology {
            let topoPresets = config.presets.filter { $0.topologyId == currentTopo.id }
            if let rememberedId = config.activePresetIdMap[currentTopo.id],
               let found = topoPresets.first(where: { $0.id == rememberedId }) {
                self.activePreset = found
            } else if let defaultP = topoPresets.first(where: { $0.isDefault }) {
                self.activePreset = defaultP
                config.activePresetIdMap[currentTopo.id] = defaultP.id
            } else {
                self.activePreset = topoPresets.first
                if let firstId = topoPresets.first?.id {
                    config.activePresetIdMap[currentTopo.id] = firstId
                }
            }
        } else {
            self.activePreset = nil
        }
        self.activePresetIdMap = config.activePresetIdMap

        // 同步兼容视图模型
        self.profiles = config.profiles
        self.activeProfile = config.activeProfile

        // 3. 应用别名映射到当前屏幕列表
        let aliasMap = currentDisplayAliases()
        for i in 0..<currentDisplays.count {
            if let alias = aliasMap[currentDisplays[i].uuid] {
                currentDisplays[i].alias = alias
            }
        }
        self.displays = currentDisplays

        // 同步确保 activeTopology.displays 中也保持别名
        if var currentTopo = self.activeTopology {
            var topoModified = false
            for i in 0..<currentTopo.displays.count {
                if let alias = aliasMap[currentTopo.displays[i].uuid], currentTopo.displays[i].alias != alias {
                    currentTopo.displays[i].alias = alias
                    topoModified = true
                }
            }
            if topoModified {
                self.activeTopology = currentTopo
                if let topoIdx = config.topologies.firstIndex(where: { $0.id == currentTopo.id }) {
                    config.topologies[topoIdx] = currentTopo
                    store.save(config: config)
                }
            }
        }

        // 4. 合并窗口条目
        let savedItems = activePreset?.items ?? []
        let currentSnap = windowManager.captureSnapshot(displayAliases: aliasMap)
        var mergedItems: [WindowLayoutItem] = []
        var matchedSavedIndices = Set<Int>()

        for snap in currentSnap {
            // 智能匹配逻辑：
            // 1. 若当前窗口具有明确标题，优先寻找相同 bundleIdentifier、相同 profile 且相同标题的预设条目
            // 2. 否则按 windowIndex 匹配（但若两者标题不同且均非空，则拒绝错位匹配）
            var matchedIndex: Int? = nil
            if let snapTitle = snap.windowTitle, !snapTitle.isEmpty {
                matchedIndex = savedItems.indices.first { i in
                    !matchedSavedIndices.contains(i) &&
                    savedItems[i].bundleIdentifier == snap.bundleIdentifier &&
                    savedItems[i].profile == snap.profile &&
                    savedItems[i].windowTitle == snapTitle
                }
            }

            if matchedIndex == nil {
                matchedIndex = savedItems.indices.first { i in
                    guard !matchedSavedIndices.contains(i),
                          savedItems[i].bundleIdentifier == snap.bundleIdentifier,
                          savedItems[i].profile == snap.profile,
                          savedItems[i].windowIndex == snap.windowIndex else { return false }

                    // 若两者皆有非空标题，且不相同，则不应盲目按 index 覆盖（防止启动器和会话窗口混淆）
                    if let snapTitle = snap.windowTitle, !snapTitle.isEmpty,
                       let savedTitle = savedItems[i].windowTitle, !savedTitle.isEmpty,
                       snapTitle != savedTitle {
                        return false
                    }
                    return true
                }
            }

            if let idx = matchedIndex {
                matchedSavedIndices.insert(idx)
                let saved = savedItems[idx]
                var item = snap
                item.isRecorded = true
                item.relativeFrame = saved.relativeFrame
                item.targetDisplayUUID = saved.targetDisplayUUID
                item.targetDisplayAlias = saved.targetDisplayAlias ?? aliasMap[saved.targetDisplayUUID ?? ""]
                item.targetDisplayWidth = saved.targetDisplayWidth
                item.targetDisplayHeight = saved.targetDisplayHeight
                item.targetDisplayIsMain = saved.targetDisplayIsMain
                item.isFullScreen = saved.isFullScreen ?? snap.isFullScreen
                item.isMinimized = saved.isMinimized ?? snap.isMinimized
                mergedItems.append(item)
            } else {
                var item = snap
                item.isRecorded = false
                mergedItems.append(item)
            }
        }

        for (i, saved) in savedItems.enumerated() {
            if !matchedSavedIndices.contains(i) {
                var inactive = saved
                inactive.isRecorded = true
                inactive.targetDisplayAlias = saved.targetDisplayAlias ?? aliasMap[saved.targetDisplayUUID ?? ""]
                mergedItems.append(inactive)
            }
        }

        displayedItems = mergedItems
    }

    // MARK: - Topology Operations
    public func renameTopology(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var config = store.load()
        guard let idx = config.topologies.firstIndex(where: { $0.id == id }) else { return }
        config.topologies[idx].name = trimmed
        config.topologies[idx].updatedAt = Date()
        store.save(config: config)

        self.topologies = config.topologies
        if activeTopology?.id == id {
            activeTopology?.name = trimmed
        }
        statusMessage = "已重命名屏幕环境为：\(trimmed)"
        refresh(forceHardwareSync: false)
    }

    public func createTopology(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var currentDisplays = displayManager.getCurrentDisplays()
        let aliasMap = currentDisplayAliases()
        for i in 0..<currentDisplays.count {
            if let alias = aliasMap[currentDisplays[i].uuid] {
                currentDisplays[i].alias = alias
            }
        }
        let currentFingerprint = DisplayManager.computeTopologyFingerprint(displays: currentDisplays)
        let currentSnap = windowManager.captureSnapshot(displayAliases: aliasMap)

        let newTopo = DisplayTopology(
            name: trimmed,
            topologyFingerprint: currentFingerprint,
            displays: currentDisplays
        )
        let defaultPreset = WindowPreset(
            topologyId: newTopo.id,
            name: "默认方案",
            isDefault: true,
            items: currentSnap
        )

        var config = store.load()
        config.topologies.append(newTopo)
        config.presets.append(defaultPreset)
        config.activeTopologyId = newTopo.id
        config.activePresetIdMap[newTopo.id] = defaultPreset.id
        store.save(config: config)

        self.topologies = config.topologies
        self.presets = config.presets
        self.activeTopology = newTopo
        self.activePreset = defaultPreset
        self.activePresetIdMap = config.activePresetIdMap
        self.isNewTopologyDetected = false
        self.statusMessage = "已创建屏幕环境【\(trimmed)】及默认方案"
        refresh(forceHardwareSync: true)
    }

    public func deleteTopology(id: UUID) {
        var config = store.load()
        guard config.topologies.count > 1 else {
            statusMessage = "至少保留一个屏幕环境"
            return
        }

        config.topologies.removeAll { $0.id == id }
        config.presets.removeAll { $0.topologyId == id }
        config.activePresetIdMap.removeValue(forKey: id)
        if config.activeTopologyId == id {
            config.activeTopologyId = config.topologies.first?.id
        }
        store.save(config: config)

        self.topologies = config.topologies
        self.presets = config.presets
        self.activeTopology = config.topologies.first
        self.activePresetIdMap = config.activePresetIdMap
        statusMessage = "已删除屏幕环境"
        refresh(forceHardwareSync: true)
    }

    public func switchTopology(id: UUID) {
        var config = store.load()
        guard let targetTopo = config.topologies.first(where: { $0.id == id }) else { return }
        config.activeTopologyId = id
        store.save(config: config)

        self.activeTopology = targetTopo
        let availablePresets = config.presets.filter { $0.topologyId == id }
        if let rememberedId = config.activePresetIdMap[id], let found = availablePresets.first(where: { $0.id == rememberedId }) {
            self.activePreset = found
        } else {
            self.activePreset = availablePresets.first(where: { $0.isDefault }) ?? availablePresets.first
        }
        self.statusMessage = "已切换至屏幕环境：\(targetTopo.name)"
        refresh(forceHardwareSync: false)
    }

    // MARK: - Preset Operations
    public func saveCurrentAsPreset(name: String, isDefault: Bool = false) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let currentTopo = activeTopology else {
            createTopology(name: "默认环境")
            return
        }

        let aliasMap = currentDisplayAliases()
        let currentSnap = windowManager.captureSnapshot(displayAliases: aliasMap)

        let newPreset = WindowPreset(
            topologyId: currentTopo.id,
            name: trimmed,
            isDefault: isDefault,
            items: currentSnap
        )

        var config = store.load()
        if isDefault {
            for i in 0..<config.presets.count where config.presets[i].topologyId == currentTopo.id {
                config.presets[i].isDefault = false
            }
        }
        config.presets.append(newPreset)
        config.activePresetIdMap[currentTopo.id] = newPreset.id
        store.save(config: config)

        self.presets = config.presets
        self.activePreset = newPreset
        self.activePresetIdMap = config.activePresetIdMap
        self.statusMessage = "已为环境【\(currentTopo.name)】新建方案：\(trimmed)"
        refresh(forceHardwareSync: false)
    }

    public func switchPreset(id: UUID) {
        var config = store.load()
        guard let targetPreset = config.presets.first(where: { $0.id == id }) else { return }
        if let topo = activeTopology {
            config.activePresetIdMap[topo.id] = id
            store.save(config: config)
            self.activePresetIdMap[topo.id] = id
        }
        self.activePreset = targetPreset
        self.statusMessage = "已切换至方案：\(targetPreset.name)"
        refresh(forceHardwareSync: false)
    }

    public func renamePreset(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var config = store.load()
        guard let index = config.presets.firstIndex(where: { $0.id == id }) else { return }
        config.presets[index].name = trimmed
        config.presets[index].updatedAt = Date()
        store.save(config: config)

        self.presets = config.presets
        if activePreset?.id == id {
            activePreset?.name = trimmed
        }
        statusMessage = "已重命名方案为：\(trimmed)"
        refresh(forceHardwareSync: false)
    }

    public func deletePreset(id: UUID) {
        guard let currentTopo = activeTopology else { return }
        let topoPresets = presets.filter { $0.topologyId == currentTopo.id }
        guard topoPresets.count > 1 else {
            statusMessage = "当前环境至少保留一个方案"
            return
        }

        var config = store.load()
        config.presets.removeAll { $0.id == id }
        let remaining = config.presets.filter { $0.topologyId == currentTopo.id }
        let nextActive = remaining.first(where: { $0.isDefault }) ?? remaining.first
        if let nextId = nextActive?.id {
            config.activePresetIdMap[currentTopo.id] = nextId
            self.activePreset = nextActive
            self.activePresetIdMap[currentTopo.id] = nextId
        }
        store.save(config: config)
        self.presets = config.presets
        statusMessage = "已删除方案"
        refresh(forceHardwareSync: false)
    }

    // MARK: - Compatibility Methods
    public func saveCurrentAsProfile(name: String) {
        if isNewTopologyDetected || activeTopology == nil {
            createTopology(name: name)
        } else {
            saveCurrentAsPreset(name: name)
        }
    }

    public func switchProfile(id: UUID) {
        if let foundPreset = presets.first(where: { $0.id == id }) {
            if foundPreset.topologyId != activeTopology?.id {
                switchTopology(id: foundPreset.topologyId)
            }
            switchPreset(id: id)
        } else if topologies.contains(where: { $0.id == id }) {
            switchTopology(id: id)
        }
    }

    public func renameProfile(id: UUID, newName: String) {
        if presets.contains(where: { $0.id == id }) {
            renamePreset(id: id, newName: newName)
        } else if topologies.contains(where: { $0.id == id }) {
            renameTopology(id: id, newName: newName)
        }
    }

    public func deleteProfile(id: UUID) {
        if presets.contains(where: { $0.id == id }) {
            deletePreset(id: id)
        } else if topologies.contains(where: { $0.id == id }) {
            deleteTopology(id: id)
        }
    }

    // MARK: - Display Alias Cascading Update
    public func updateDisplayAlias(displayUUID: String, alias: String) {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        let newAlias = trimmed.isEmpty ? nil : trimmed
        var config = store.load()

        // 1. 更新全局持久化映射表
        if let newAlias = newAlias {
            config.displayAliases[displayUUID] = newAlias
        } else {
            config.displayAliases.removeValue(forKey: displayUUID)
        }

        // 2. 更新全部拓扑中的对应屏幕别名 (无论是否当前环境)
        for tIdx in 0..<config.topologies.count {
            if let dIdx = config.topologies[tIdx].displays.firstIndex(where: { $0.uuid == displayUUID }) {
                config.topologies[tIdx].displays[dIdx].alias = newAlias
            }
        }

        if var currentTopo = activeTopology {
            if let dIdx = currentTopo.displays.firstIndex(where: { $0.uuid == displayUUID }) {
                currentTopo.displays[dIdx].alias = newAlias
            } else if let activeScreen = displays.first(where: { $0.uuid == displayUUID }) {
                var newD = activeScreen
                newD.alias = newAlias
                currentTopo.displays.append(newD)
            }
            currentTopo.updatedAt = Date()
            if let topoIdx = config.topologies.firstIndex(where: { $0.id == currentTopo.id }) {
                config.topologies[topoIdx] = currentTopo
            }
            self.activeTopology = currentTopo
        }

        // 3. 级联更新全部方案中的 targetDisplayAlias
        for i in 0..<config.presets.count {
            for j in 0..<config.presets[i].items.count {
                if config.presets[i].items[j].targetDisplayUUID == displayUUID {
                    config.presets[i].items[j].targetDisplayAlias = newAlias
                }
            }
        }
        self.presets = config.presets
        if let ap = self.activePreset, let refreshed = config.presets.first(where: { $0.id == ap.id }) {
            self.activePreset = refreshed
        }

        // 4. 立即同步更新当前运行时的 displays 数组
        if let liveIdx = displays.firstIndex(where: { $0.uuid == displayUUID }) {
            displays[liveIdx].alias = newAlias
        }

        store.save(config: config)
        statusMessage = "已更新显示器别名：\(trimmed.isEmpty ? "已重置" : trimmed)"
        refresh(forceHardwareSync: false)
    }

    // MARK: - Snapshot & Restore
    public func snapshotAll() {
        let aliasMap = currentDisplayAliases()
        let items = windowManager.captureSnapshot(displayAliases: aliasMap)
        var currentDisplays = displayManager.getCurrentDisplays()
        for i in 0..<currentDisplays.count {
            if let alias = aliasMap[currentDisplays[i].uuid] {
                currentDisplays[i].alias = alias
            }
        }
        let currentFingerprint = DisplayManager.computeTopologyFingerprint(displays: currentDisplays)

        var config = store.load()
        guard var topo = activeTopology,
              let topoIdx = config.topologies.firstIndex(where: { $0.id == topo.id }),
              var preset = activePreset,
              let presetIdx = config.presets.firstIndex(where: { $0.id == preset.id }) else {
            createTopology(name: "默认环境")
            return
        }

        topo.displays = currentDisplays
        topo.topologyFingerprint = currentFingerprint
        topo.updatedAt = Date()
        config.topologies[topoIdx] = topo
        self.activeTopology = topo

        // 同步保持全局 displayAliases 池
        for d in currentDisplays {
            if let a = d.alias {
                config.displayAliases[d.uuid] = a
            }
        }

        preset.items = items
        preset.updatedAt = Date()
        config.presets[presetIdx] = preset
        self.activePreset = preset

        config.autoQuitAfterRestore = autoQuitAfterRestore
        config.autoRestoreOnProfileMatch = autoRestoreOnProfileMatch
        store.save(config: config)

        statusMessage = "已快照保存 \(items.count) 个窗口至【\(topo.name) · \(preset.name)】"
        refresh(forceHardwareSync: false)
    }

    public func restoreAll() {
        guard let preset = activePreset else { return }
        let aliasMap = currentDisplayAliases()
        let items = preset.items
        let autoQuit = autoQuitAfterRestore
        let windowMgr = windowManager

        statusMessage = "正在执行窗口归位..."
        Task.detached(priority: .userInitiated) { [weak self] in
            var count = 0
            for item in items {
                if windowMgr.restore(item: item, displayAliases: aliasMap) {
                    count += 1
                }
                // 微小让步 100ms，防止多窗口连续切换动画引发 WindowServer 事件丢包
                usleep(100_000)
            }
            let finalCount = count
            await MainActor.run { [weak self] in
                self?.statusMessage = "已全部归位：成功复原 \(finalCount) 个窗口"
                if autoQuit {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }

    public func recordItem(_ item: WindowLayoutItem) {
        let aliasMap = currentDisplayAliases()
        let currentWindows = windowManager.captureSnapshot(displayAliases: aliasMap)

        // 智能定位实时窗口：优先依据 (bundleIdentifier, profile, windowTitle) 精准匹配
        let currentWindow: WindowLayoutItem? = {
            if let targetTitle = item.windowTitle, !targetTitle.isEmpty {
                if let match = currentWindows.first(where: {
                    $0.bundleIdentifier == item.bundleIdentifier &&
                    $0.profile == item.profile &&
                    $0.windowTitle == targetTitle
                }) {
                    return match
                }
            }
            return currentWindows.first(where: { $0.id == item.id })
        }()

        guard let current = currentWindow else {
            statusMessage = "未找到 \(item.appName) 当前打开的窗口"
            return
        }

        var config = store.load()
        guard var preset = activePreset,
              let idx = config.presets.firstIndex(where: { $0.id == preset.id }) else { return }

        preset.items.removeAll { saved in
            if let targetTitle = item.windowTitle, !targetTitle.isEmpty,
               let savedTitle = saved.windowTitle, !savedTitle.isEmpty {
                return saved.bundleIdentifier == item.bundleIdentifier &&
                       saved.profile == item.profile &&
                       savedTitle == targetTitle
            }
            return saved.id == item.id
        }
        preset.items.append(current)
        preset.updatedAt = Date()
        config.presets[idx] = preset
        store.save(config: config)

        self.activePreset = preset
        let titleSuffix = (item.windowTitle != nil && !item.windowTitle!.isEmpty && item.windowTitle != item.appName) ? " (\(item.windowTitle!))" : ""
        let name = item.profile != nil ? "\(item.appName) [\(item.profile!)]\(titleSuffix)" : "\(item.appName)\(titleSuffix)"
        statusMessage = "已记录 \(name) 位置至方案【\(preset.name)】"
        refresh()
    }

    public func restoreItem(_ item: WindowLayoutItem) {
        let aliasMap = currentDisplayAliases()
        let windowMgr = windowManager
        Task.detached(priority: .userInitiated) { [weak self] in
            let success = windowMgr.restore(item: item, displayAliases: aliasMap)
            await MainActor.run { [weak self] in
                if success {
                    self?.statusMessage = "已归位 \(item.appName)"
                } else {
                    self?.statusMessage = "未找到 \(item.appName) 窗口，请确认是否已打开"
                }
            }
        }
    }

    public func removeItem(_ item: WindowLayoutItem) {
        var config = store.load()
        guard var preset = activePreset,
              let idx = config.presets.firstIndex(where: { $0.id == preset.id }) else { return }

        preset.items.removeAll { saved in
            if let targetTitle = item.windowTitle, !targetTitle.isEmpty,
               let savedTitle = saved.windowTitle, !savedTitle.isEmpty {
                return saved.bundleIdentifier == item.bundleIdentifier &&
                       saved.profile == item.profile &&
                       savedTitle == targetTitle
            }
            return saved.id == item.id
        }
        preset.updatedAt = Date()
        config.presets[idx] = preset
        store.save(config: config)

        self.activePreset = preset
        let titleSuffix = (item.windowTitle != nil && !item.windowTitle!.isEmpty && item.windowTitle != item.appName) ? " (\(item.windowTitle!))" : ""
        statusMessage = "已从方案【\(preset.name)】中移除 \(item.appName)\(titleSuffix) 预设"
        refresh()
    }

    public func updateAutoQuit(_ enabled: Bool) {
        autoQuitAfterRestore = enabled
        var config = store.load()
        config.autoQuitAfterRestore = enabled
        store.save(config: config)
    }

    public func updateAutoRestoreOnProfileMatch(_ enabled: Bool) {
        autoRestoreOnProfileMatch = enabled
        var config = store.load()
        config.autoRestoreOnProfileMatch = enabled
        store.save(config: config)
    }

    public static func createDemoState() -> AppState {
        let isZh = LocalizationService.shared.effectiveLanguage == .zhHans
        let mockDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let state = AppState(store: LayoutStore(storageDirectory: mockDir))
        state.hasPermission = true

        let dispMain = DisplayInfo(id: 1, uuid: "DISP-MAIN-001", name: "Studio Display 27\"", alias: isZh ? "带鱼主屏" : "UltraWide Main", isMain: true, boundsWidth: 2560, boundsHeight: 1440, originX: 0, originY: 0)
        let dispPort = DisplayInfo(id: 2, uuid: "DISP-PORT-002", name: "Dell U2723QE", alias: isZh ? "左侧竖屏" : "Portrait Left", isMain: false, boundsWidth: 1080, boundsHeight: 1920, originX: -1080, originY: 0)
        let dispBuiltin = DisplayInfo(id: 3, uuid: "DISP-BUILTIN-003", name: "Built-in Liquid Retina XDR", alias: isZh ? "笔记本内屏" : "Built-in Display", isMain: false, boundsWidth: 1512, boundsHeight: 982, originX: 2560, originY: 0)

        state.displays = [dispMain, dispPort, dispBuiltin]

        let fingerprint = DisplayManager.computeTopologyFingerprint(displays: state.displays)
        let topo = DisplayTopology(
            id: UUID(),
            name: isZh ? "办公室三屏环境" : "Studio Tri-Display",
            topologyFingerprint: fingerprint,
            displays: state.displays
        )

        state.topologies = [topo]
        state.activeTopology = topo

        let preset = WindowPreset(
            id: UUID(),
            topologyId: topo.id,
            name: isZh ? "沉浸开发模式" : "Coding Focus Mode",
            items: []
        )
        state.presets = [preset]
        state.activePreset = preset

        let itemXcode = WindowLayoutItem(
            bundleIdentifier: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowIndex: 0,
            windowTitle: "MacDeck.xcodeproj — WindowManager.swift",
            targetDisplayUUID: dispMain.uuid,
            targetDisplayAlias: dispMain.alias,
            targetDisplayWidth: dispMain.boundsWidth,
            targetDisplayHeight: dispMain.boundsHeight,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0.05, y: 0.05, width: 0.70, height: 0.85),
            isRecorded: true,
            isFullScreen: false,
            isMinimized: false
        )

        let itemChrome = WindowLayoutItem(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            profile: "Dev",
            windowIndex: 1,
            windowTitle: "GitHub - zhenqiang-sun/macdeck",
            targetDisplayUUID: dispPort.uuid,
            targetDisplayAlias: dispPort.alias,
            targetDisplayWidth: dispPort.boundsWidth,
            targetDisplayHeight: dispPort.boundsHeight,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 0.02, y: 0.02, width: 0.95, height: 0.95),
            isRecorded: true,
            isFullScreen: false,
            isMinimized: false
        )

        let itemTerminal = WindowLayoutItem(
            bundleIdentifier: "com.apple.Terminal",
            appName: "Terminal",
            windowIndex: 2,
            windowTitle: "zsh — swift test -v",
            targetDisplayUUID: dispPort.uuid,
            targetDisplayAlias: dispPort.alias,
            targetDisplayWidth: dispPort.boundsWidth,
            targetDisplayHeight: dispPort.boundsHeight,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 0, y: 0, width: 1.0, height: 1.0),
            isRecorded: true,
            isFullScreen: true,
            isMinimized: false
        )

        let itemFigma = WindowLayoutItem(
            bundleIdentifier: "com.figma.Desktop",
            appName: "Figma",
            windowIndex: 3,
            windowTitle: "MacDeck Design System & Bento Layout",
            targetDisplayUUID: dispMain.uuid,
            targetDisplayAlias: dispMain.alias,
            targetDisplayWidth: dispMain.boundsWidth,
            targetDisplayHeight: dispMain.boundsHeight,
            targetDisplayIsMain: true,
            relativeFrame: RelativeRect(x: 0.2, y: 0.1, width: 0.75, height: 0.8),
            isRecorded: true,
            isFullScreen: false,
            isMinimized: false
        )

        let itemSlack = WindowLayoutItem(
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            appName: "Slack",
            windowIndex: 4,
            windowTitle: "#open-source-contributors",
            targetDisplayUUID: dispBuiltin.uuid,
            targetDisplayAlias: dispBuiltin.alias,
            targetDisplayWidth: dispBuiltin.boundsWidth,
            targetDisplayHeight: dispBuiltin.boundsHeight,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
            isRecorded: true,
            isFullScreen: false,
            isMinimized: true
        )

        let itemMusic = WindowLayoutItem(
            bundleIdentifier: "com.apple.Music",
            appName: "Music",
            windowIndex: 5,
            windowTitle: "Apple Music — Lo-Fi Chill Beats",
            targetDisplayUUID: dispBuiltin.uuid,
            targetDisplayAlias: dispBuiltin.alias,
            targetDisplayWidth: dispBuiltin.boundsWidth,
            targetDisplayHeight: dispBuiltin.boundsHeight,
            targetDisplayIsMain: false,
            relativeFrame: RelativeRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7),
            isRecorded: false,
            isFullScreen: false,
            isMinimized: false
        )

        state.displayedItems = [itemXcode, itemChrome, itemTerminal, itemFigma, itemSlack, itemMusic]
        return state
    }
}
