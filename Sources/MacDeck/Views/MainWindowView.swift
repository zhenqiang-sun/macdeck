import SwiftUI
import AppKit

enum RecordStatusFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case recorded = "recorded"
    case unrecorded = "unrecorded"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "filter.all_status".localized
        case .recorded: return "filter.recorded".localized
        case .unrecorded: return "filter.unrecorded".localized
        }
    }
}

enum WindowTypeFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case normal = "normal"
    case fullscreen = "fullscreen"
    case minimized = "minimized"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "filter.all_types".localized
        case .normal: return "filter.normal".localized
        case .fullscreen: return "filter.fullscreen_only".localized
        case .minimized: return "filter.minimized_only".localized
        }
    }
}

@MainActor
struct MainWindowView: View {
    @StateObject private var state: AppState
    @ObservedObject private var loc = LocalizationService.shared
    @State private var selectedTab: NavigationItem
    private var customSystemInfoVM: SystemInfoViewModel?

    init() {
        _state = StateObject(wrappedValue: AppState())
        self.customSystemInfoVM = nil
        _selectedTab = State(initialValue: .systemInfo)
    }

    init(systemInfoVM: SystemInfoViewModel?, selectedTab: NavigationItem = .systemInfo) {
        _state = StateObject(wrappedValue: AppState())
        self.customSystemInfoVM = systemInfoVM
        _selectedTab = State(initialValue: selectedTab)
    }

    init(selectedTab: NavigationItem) {
        _state = StateObject(wrappedValue: AppState())
        self.customSystemInfoVM = nil
        _selectedTab = State(initialValue: selectedTab)
    }

    init(state: AppState, selectedTab: NavigationItem = .windowLayout) {
        _state = StateObject(wrappedValue: state)
        self.customSystemInfoVM = nil
        _selectedTab = State(initialValue: selectedTab)
    }

    @State private var showingNewPresetSheet = false
    @State private var newPresetName = ""
    @State private var showingRenamePresetSheet = false
    @State private var renamePresetDraft = ""
    @State private var showingNewTopologySheet = false
    @State private var newTopologyName = ""

    // 筛选状态
    @State private var selectedDisplayFilter: String = "ALL"
    @State private var selectedStatusFilter: RecordStatusFilter = .all
    @State private var selectedTypeFilter: WindowTypeFilter = .all

    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, selection: $selectedTab) { item in
                NavigationLink(value: item) {
                    HStack(spacing: 6) {
                        Label(item.title, systemImage: item.icon)
                            .font(.system(size: 13, weight: .medium))

                        Spacer()

                        if item == .softwareUpdate && state.pendingUpdateCount > 0 {
                            Text("\(state.pendingUpdateCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DeckTheme.Colors.danger)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 200)
        } detail: {
            Group {
                switch selectedTab {
                case .systemInfo:
                    SystemInfoView(viewModel: customSystemInfoVM ?? SystemInfoViewModel())
                case .windowLayout:
                    windowLayoutView
                case .displays:
                    DisplaysOverviewView(state: state)
                case .softwareUpdate:
                    SoftwareUpdateView()
                case .environment:
                    EnvironmentMaintenanceView()
                case .settings:
                    SettingsView(state: state)
                }
            }
            .frame(minWidth: 540, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity, alignment: .top)
            .background(Color(NSColor.windowBackgroundColor))
            .clipped()
        }
        .frame(minWidth: 780, idealWidth: 820, minHeight: 580)
        .id(loc.effectiveLanguage)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .onAppear {
            state.refresh(forceHardwareSync: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.checkPermission()
            state.refresh(forceHardwareSync: true)
        }
        .sheet(isPresented: $showingNewPresetSheet) {
            VStack(spacing: 16) {
                Text(String(format: "displays.create_preset_desc".localized, state.activeTopology?.name ?? "displays.current_env_badge".localized))
                    .font(.headline)

                Text("displays.auto_match_hint".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("displays.preset_name_placeholder".localized, text: $newPresetName)
                    .textFieldStyle(DeckTextFieldStyle())
                    .frame(width: 280)

                HStack(spacing: 12) {
                    Button("common.cancel".localized) {
                        showingNewPresetSheet = false
                    }
                    .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                    .keyboardShortcut(.cancelAction)

                    Button("common.save".localized) {
                        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                        state.saveCurrentAsPreset(name: name.isEmpty ? "displays.default_preset".localized : name)
                        showingNewPresetSheet = false
                    }
                    .deckPrimaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 380)
        }
        .sheet(isPresented: $showingRenamePresetSheet) {
            VStack(spacing: 16) {
                Text("displays.rename_preset_title".localized)
                    .font(.headline)

                TextField("displays.preset_name_placeholder".localized, text: $renamePresetDraft)
                    .textFieldStyle(DeckTextFieldStyle())
                    .frame(width: 280)

                HStack(spacing: 12) {
                    Button("common.cancel".localized) {
                        showingRenamePresetSheet = false
                    }
                    .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                    .keyboardShortcut(.cancelAction)

                    Button("common.save".localized) {
                        if let active = state.activePreset {
                            state.renamePreset(id: active.id, newName: renamePresetDraft)
                        }
                        showingRenamePresetSheet = false
                    }
                    .deckPrimaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 340)
        }
        .sheet(isPresented: $showingNewTopologySheet) {
            VStack(spacing: 16) {
                Text("displays.save_new_env".localized)
                    .font(.headline)

                Text(String(format: "displays.save_new_env_desc".localized, state.displays.count))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("displays.new_env_placeholder".localized, text: $newTopologyName)
                    .textFieldStyle(DeckTextFieldStyle())
                    .frame(width: 280)

                HStack(spacing: 12) {
                    Button("common.cancel".localized) {
                        showingNewTopologySheet = false
                    }
                    .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                    .keyboardShortcut(.cancelAction)

                    Button("displays.create_activate".localized) {
                        let name = newTopologyName.trimmingCharacters(in: .whitespacesAndNewlines)
                        state.createTopology(name: name.isEmpty ? "displays.unconfigured_env".localized : name)
                        showingNewTopologySheet = false
                    }
                    .deckPrimaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 380)
        }
    }

    private var isFilterActive: Bool {
        selectedDisplayFilter != "ALL" || selectedStatusFilter != .all || selectedTypeFilter != .all
    }

    private var filteredItems: [WindowLayoutItem] {
        state.displayedItems.filter { item in
            // 1. 屏幕别名/UUID筛选
            if selectedDisplayFilter != "ALL" {
                let matchUUID = (item.targetDisplayUUID == selectedDisplayFilter)
                let matchAlias = (item.targetDisplayAlias == selectedDisplayFilter)
                if !matchUUID && !matchAlias {
                    return false
                }
            }

            // 2. 记录状态筛选
            switch selectedStatusFilter {
            case .all:
                break
            case .recorded:
                if !item.isRecorded { return false }
            case .unrecorded:
                if item.isRecorded { return false }
            }

            // 3. 窗口形态筛选
            switch selectedTypeFilter {
            case .all:
                break
            case .fullscreen:
                if item.isFullScreen != true { return false }
            case .minimized:
                if item.isMinimized != true { return false }
            case .normal:
                if item.isFullScreen == true || item.isMinimized == true { return false }
            }

            return true
        }
    }

    private func itemCount(for display: DisplayInfo) -> Int {
        state.displayedItems.filter { item in
            item.targetDisplayUUID == display.uuid || item.targetDisplayAlias == display.displayName
        }.count
    }

    var windowLayoutView: some View {
        VStack(spacing: 12) {
            // 权限提示
            if !state.hasPermission {
                PermissionBannerView {
                    WindowManager.requestAccessibilityPermission()
                    state.checkPermission()
                }
            }

            // 统一规范的页面 Header
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("nav.window_layout".localized)
                            .font(.system(size: 18, weight: .bold))

                        // 环境状态标识
                        if let topo = state.activeTopology {
                            if state.isCurrentProfileHardwareMatched {
                                HStack(spacing: 4) {
                                    Circle().fill(DeckTheme.Colors.success).frame(width: 6, height: 6)
                                    Text(topo.name)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(DeckTheme.Colors.success.opacity(0.12))
                                .foregroundColor(DeckTheme.Colors.success)
                                .cornerRadius(DeckTheme.CornerRadius.badge)
                            } else if state.isNewTopologyDetected {
                                Button(action: { selectedTab = .displays }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 10))
                                        Text(String(format: "displays.unnamed_topology".localized, state.displays.count))
                                            .font(.system(size: 11, weight: .semibold))
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 8))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(DeckTheme.Colors.infoBlue.opacity(0.12))
                                    .foregroundColor(DeckTheme.Colors.infoBlue)
                                    .cornerRadius(DeckTheme.CornerRadius.badge)
                                }
                                .buttonStyle(.plain)
                                .help("displays.go_to_displays_help".localized)
                            } else {
                                HStack(spacing: 6) {
                                    HStack(spacing: 4) {
                                        Text(topo.name)
                                            .font(.system(size: 11, weight: .semibold))
                                        Circle().fill(DeckTheme.Colors.warning).frame(width: 6, height: 6)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(DeckTheme.Colors.warning.opacity(0.12))
                                    .foregroundColor(DeckTheme.Colors.warning)
                                    .cornerRadius(DeckTheme.CornerRadius.badge)

                                    Button("displays.align_hardware".localized, action: { state.alignWithCurrentHardware() })
                                        .deckCompactButton(isProminent: false)
                                }
                            }
                        }
                    }

                    Text("displays.subtitle".localized)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 业务方案下拉切换菜单
                Menu {
                    ForEach(state.presetsForActiveTopology) { preset in
                        Button(action: { state.switchPreset(id: preset.id) }) {
                            HStack {
                                Text(preset.name)
                                if preset.id == state.activePreset?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button("+ \("displays.add_preset".localized)...") {
                        newPresetName = ""
                        showingNewPresetSheet = true
                    }

                    if let activePreset = state.activePreset {
                        Button("\("displays.rename_preset".localized)...") {
                            renamePresetDraft = activePreset.name
                            showingRenamePresetSheet = true
                        }

                        if state.presetsForActiveTopology.count > 1 {
                            Button("\("displays.delete_preset".localized)...", role: .destructive) {
                                state.deletePreset(id: activePreset.id)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DeckTheme.Colors.accent)

                        Text(state.activePreset?.name ?? "displays.default_preset".localized)
                            .font(.system(size: 12, weight: .semibold))

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: DeckTheme.ControlHeight.regular)
                    .background(DeckTheme.Colors.secondaryFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.button)
                            .stroke(DeckTheme.Colors.subtleBorder, lineWidth: 1)
                    )
                    .cornerRadius(DeckTheme.CornerRadius.button)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button(action: { state.refresh(forceHardwareSync: true) }) {
                    Image(systemName: "arrow.clockwise")
                }
                .deckIconButton(size: DeckTheme.ControlHeight.iconRegular, cornerRadius: DeckTheme.CornerRadius.button)
                .help("displays.rescan_help".localized)
            }

            Divider()

            // 核心操作区 (严格对齐 30pt 高度与 7pt 圆角)
            HStack(spacing: 10) {
                Button(action: {
                    state.restoreAll()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("\("displays.restore_all".localized) (⌘↵)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .deckPrimaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                .keyboardShortcut(.return, modifiers: [.command])

                Button(action: {
                    state.snapshotAll()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("displays.snapshot_all".localized)
                    }
                    .frame(maxWidth: .infinity)
                }
                .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                .keyboardShortcut("s", modifiers: [.command])
            }

            // 状态反馈提示
            if let msg = state.statusMessage {
                Text(msg)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DeckTheme.Colors.accent)
                    .padding(.vertical, 1)
            }

            // 筛选工具栏
            HStack(spacing: 8) {
                // 屏幕胶囊组 (使用统一凹槽底板)
                ScrollView(.horizontal, showsIndicators: false) {
                    DeckSegmentedContainer {
                        DeckSegmentedItem(
                            title: "common.all".localized,
                            count: state.displayedItems.count,
                            isSelected: selectedDisplayFilter == "ALL"
                        ) {
                            selectedDisplayFilter = "ALL"
                        }

                        ForEach(state.displays) { d in
                            let count = itemCount(for: d)
                            let isSelected = (selectedDisplayFilter == d.uuid || selectedDisplayFilter == d.displayName)
                            DeckSegmentedItem(
                                title: d.displayName,
                                count: count,
                                isSelected: isSelected
                            ) {
                                selectedDisplayFilter = isSelected ? "ALL" : d.uuid
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 4)

                // 状态筛选
                Menu {
                    ForEach(RecordStatusFilter.allCases) { filter in
                        Button(action: { selectedStatusFilter = filter }) {
                            HStack {
                                Text(filter.displayName)
                                if selectedStatusFilter == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedStatusFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 10))
                        Text(selectedStatusFilter == .all ? "filter.status".localized : selectedStatusFilter.displayName)
                            .font(.system(size: 11, weight: selectedStatusFilter == .all ? .regular : .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(selectedStatusFilter == .all ? DeckTheme.Colors.secondaryFill : DeckTheme.Colors.accent.opacity(0.15))
                    .foregroundColor(selectedStatusFilter == .all ? .secondary : DeckTheme.Colors.accent)
                    .cornerRadius(DeckTheme.CornerRadius.compact)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // 形态筛选
                Menu {
                    ForEach(WindowTypeFilter.allCases) { filter in
                        Button(action: { selectedTypeFilter = filter }) {
                            HStack {
                                Text(filter.displayName)
                                if selectedTypeFilter == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedTypeFilter == .all ? "macwindow" : "macwindow.badge.plus")
                            .font(.system(size: 10))
                        Text(selectedTypeFilter == .all ? "filter.type".localized : selectedTypeFilter.displayName)
                            .font(.system(size: 11, weight: selectedTypeFilter == .all ? .regular : .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(selectedTypeFilter == .all ? DeckTheme.Colors.secondaryFill : DeckTheme.Colors.accent.opacity(0.15))
                    .foregroundColor(selectedTypeFilter == .all ? .secondary : DeckTheme.Colors.accent)
                    .cornerRadius(DeckTheme.CornerRadius.compact)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if isFilterActive {
                    Button(action: {
                        selectedDisplayFilter = "ALL"
                        selectedStatusFilter = .all
                        selectedTypeFilter = .all
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("filter.clear".localized)
                }
            }
            .padding(.horizontal, 2)

            // 应用列表 (撑满剩余纵向空间，消除居中空白)
            ScrollView {
                LazyVStack(spacing: 8) {
                    if state.displayedItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "macwindow.on.rectangle")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("windowRow.no_windows".localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else if filteredItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("filter.no_match".localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Button("filter.reset".localized) {
                                selectedDisplayFilter = "ALL"
                                selectedStatusFilter = .all
                                selectedTypeFilter = .all
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                    } else {
                        ForEach(filteredItems) { item in
                            AppRowView(
                                item: item,
                                onRecord: { state.recordItem(item) },
                                onRestore: { state.restoreItem(item) },
                                onRemove: { state.removeItem(item) }
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // 底部偏好与快捷键说明
            HStack {
                Toggle("settings.auto_quit".localized, isOn: Binding(
                    get: { state.autoQuitAfterRestore },
                    set: { state.updateAutoQuit($0) }
                ))
                .font(.system(size: 11))

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Text("common.quit".localized)
                        Text("⌘Q")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(3)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 11))
                .keyboardShortcut("q", modifiers: [.command])
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
