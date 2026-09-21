import SwiftUI

struct DisplaysOverviewView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var loc = LocalizationService.shared
    @State private var editingUUID: String? = nil
    @State private var aliasDraft: String = ""

    @State private var showingRenameTopologySheet = false
    @State private var topologyNameDraft: String = ""
    @State private var showingNewTopologySheet = false
    @State private var newTopologyNameDraft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 统一规范的顶部 Header Bar
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("displays.page_title".localized)
                        .font(.system(size: 18, weight: .bold))
                    Text("displays.page_subtitle".localized)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        state.refresh(forceHardwareSync: true)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                            Text("displays.detect_hardware".localized)
                        }
                    }
                    .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)

                    if state.isNewTopologyDetected {
                        Button(action: {
                            newTopologyNameDraft = "\("displays.save_as_new_env".localized) \(state.topologies.count + 1)"
                            showingNewTopologySheet = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                Text("displays.save_as_new_env".localized)
                            }
                        }
                        .deckPrimaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. 顶部环境概览卡片
                    topologyOverviewCard

                    // 2. 当前物理屏幕设备列表
                    displaysSection

                    // 3. 已保存的屏幕环境管理
                    savedTopologiesSection
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingRenameTopologySheet) {
            VStack(spacing: 16) {
                Text("displays.rename_topology_title".localized)
                    .font(.headline)

                Text(String(format: "displays.new_topology_desc".localized, state.displays.count))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                TextField("displays.rename_topology_placeholder".localized, text: $topologyNameDraft)
                    .textFieldStyle(DeckTextFieldStyle())
                    .frame(width: 260)

                HStack(spacing: 12) {
                    Button("common.cancel".localized) {
                        showingRenameTopologySheet = false
                    }
                    .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                    .keyboardShortcut(.cancelAction)

                    Button("common.save".localized) {
                        if let active = state.activeTopology {
                            state.renameTopology(id: active.id, newName: topologyNameDraft)
                        }
                        showingRenameTopologySheet = false
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
                Text("displays.new_topology_title".localized)
                    .font(.headline)

                Text(String(format: "displays.new_topology_desc".localized, state.displays.count))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                TextField("displays.new_topology_placeholder".localized, text: $newTopologyNameDraft)
                    .textFieldStyle(DeckTextFieldStyle())
                    .frame(width: 260)

                HStack(spacing: 12) {
                    Button("common.cancel".localized) {
                        showingNewTopologySheet = false
                    }
                    .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                    .keyboardShortcut(.cancelAction)

                    Button("common.confirm".localized) {
                        state.createTopology(name: newTopologyNameDraft)
                        showingNewTopologySheet = false
                    }
                    .deckPrimaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 340)
        }
    }

    // MARK: - 顶部环境概览卡片
    private var topologyOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "display.2")
                    .font(.system(size: 26))
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(state.activeTopology?.name ?? "displays.unconfigured_env".localized)
                            .font(.system(size: 18, weight: .bold))

                        if state.isCurrentProfileHardwareMatched {
                            HStack(spacing: 4) {
                                Circle().fill(DeckTheme.Colors.success).frame(width: 6, height: 6)
                                Text(String(format: "displays.hardware_matched".localized, state.displays.count))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DeckTheme.Colors.success)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(DeckTheme.Colors.success.opacity(0.12))
                            .cornerRadius(DeckTheme.CornerRadius.badge)
                        } else if state.isNewTopologyDetected {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text(String(format: "displays.new_topology_combo".localized, state.displays.count))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(DeckTheme.Colors.infoBlue.opacity(0.12))
                            .foregroundColor(DeckTheme.Colors.infoBlue)
                            .cornerRadius(DeckTheme.CornerRadius.badge)
                        } else {
                            HStack(spacing: 4) {
                                Circle().fill(DeckTheme.Colors.warning).frame(width: 6, height: 6)
                                Text("displays.topology_mismatched".localized)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DeckTheme.Colors.warning)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(DeckTheme.Colors.warning.opacity(0.12))
                            .cornerRadius(DeckTheme.CornerRadius.badge)
                        }
                    }

                    Text(String(format: "displays.topology_card_desc".localized, state.presetsForActiveTopology.count))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    if let active = state.activeTopology {
                        Button(action: {
                            topologyNameDraft = active.name
                            showingRenameTopologySheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                Text("displays.modify_env_name".localized)
                            }
                        }
                        .deckCompactButton(isProminent: false)
                    }

                    if state.isNewTopologyDetected {
                        Button(action: {
                            newTopologyNameDraft = "\("displays.save_as_new_env".localized) \(state.topologies.count + 1)"
                            showingNewTopologySheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("displays.save_as_new_env".localized)
                            }
                        }
                        .deckCompactButton(isProminent: true)
                    }
                }
            }
        }
        .padding(16)
        .background(DeckTheme.Colors.cardBackground)
        .cornerRadius(DeckTheme.CornerRadius.outer)
        .overlay(
            RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.outer)
                .stroke(DeckTheme.Colors.subtleBorder, lineWidth: 1)
        )
    }

    // MARK: - 显示器硬件列表
    private var displaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("displays.connected_devices_title".localized)
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text("displays.set_alias_hint".localized)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            LazyVStack(spacing: 10) {
                ForEach(state.displays) { d in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 14) {
                            Image(systemName: d.isMain ? "display" : "display.2")
                                .font(.system(size: 26))
                                .foregroundColor(d.isMain ? DeckTheme.Colors.success : DeckTheme.Colors.infoBlue)
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    if let alias = d.alias, !alias.isEmpty {
                                        Text(alias)
                                            .font(.system(size: 14, weight: .bold))
                                        Text("(\(d.name))")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(d.name)
                                            .font(.system(size: 14, weight: .semibold))
                                    }

                                    if d.isMain {
                                        Text("windowRow.main_screen_badge".localized)
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(DeckTheme.Colors.success.opacity(0.15))
                                            .foregroundColor(DeckTheme.Colors.success)
                                            .cornerRadius(DeckTheme.CornerRadius.badge)
                                    }
                                }

                                Text(String(format: "displays.resolution_format".localized, Int(d.boundsWidth), Int(d.boundsHeight), Int(d.originX), Int(d.originY)))
                                    .font(.system(size: 11))
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if editingUUID != d.uuid {
                                Button(action: {
                                    editingUUID = d.uuid
                                    aliasDraft = d.alias ?? ""
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                        Text(d.alias == nil ? "displays.set_alias".localized : "displays.edit_alias".localized)
                                    }
                                }
                                .deckCompactButton(isProminent: false)
                            }
                        }

                        if editingUUID == d.uuid {
                            HStack(spacing: 8) {
                                TextField("displays.alias_input_placeholder".localized, text: $aliasDraft, onCommit: {
                                    saveAlias(for: d)
                                })
                                .textFieldStyle(DeckTextFieldStyle())

                                Button("common.save".localized) {
                                    saveAlias(for: d)
                                }
                                .deckCompactButton(isProminent: true)

                                Button("common.cancel".localized) {
                                    editingUUID = nil
                                }
                                .deckCompactButton(isProminent: false)
                                .keyboardShortcut(.cancelAction)

                                if d.alias != nil {
                                    Button("displays.clear_alias".localized) {
                                        aliasDraft = ""
                                        saveAlias(for: d)
                                    }
                                    .deckCompactButton(isProminent: false, color: DeckTheme.Colors.danger)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(DeckTheme.Colors.cardBackground.opacity(0.85))
                    .cornerRadius(DeckTheme.CornerRadius.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.card)
                            .stroke(DeckTheme.Colors.subtleBorder, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - 已保存的屏幕拓扑环境
    private var savedTopologiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: "displays.saved_topologies_title".localized, state.topologies.count))
                .font(.system(size: 14, weight: .bold))

            LazyVStack(spacing: 8) {
                ForEach(state.topologies) { topo in
                    let isCurrent = (topo.id == state.activeTopology?.id)
                    let presetCount = state.presets.filter { $0.topologyId == topo.id }.count

                    HStack(spacing: 12) {
                        Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isCurrent ? DeckTheme.Colors.success : .secondary)
                            .font(.system(size: 16))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(topo.name)
                                    .font(.system(size: 13, weight: isCurrent ? .bold : .medium))

                                if isCurrent {
                                    Text("displays.current_env_badge".localized)
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(DeckTheme.Colors.success.opacity(0.15))
                                        .foregroundColor(DeckTheme.Colors.success)
                                        .cornerRadius(DeckTheme.CornerRadius.badge)
                                }
                            }

                            Text(String(format: "displays.topology_summary_format".localized, topo.displays.count, presetCount))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !isCurrent {
                            Button("displays.switch_to_this_env".localized) {
                                state.switchTopology(id: topo.id)
                            }
                            .deckCompactButton(isProminent: false)
                        }

                        if state.topologies.count > 1 && !isCurrent {
                            Button(action: {
                                state.deleteTopology(id: topo.id)
                            }) {
                                Image(systemName: "trash")
                            }
                            .deckIconButton(size: DeckTheme.ControlHeight.iconCompact, cornerRadius: DeckTheme.CornerRadius.compact, isDestructive: true)
                            .help("displays.delete_env_help".localized)
                        }
                    }
                    .padding(12)
                    .background(DeckTheme.Colors.cardBackground.opacity(isCurrent ? 0.85 : 0.45))
                    .cornerRadius(DeckTheme.CornerRadius.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.card)
                            .stroke(isCurrent ? DeckTheme.Colors.success.opacity(0.25) : DeckTheme.Colors.subtleBorder, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func saveAlias(for display: DisplayInfo) {
        state.updateDisplayAlias(displayUUID: display.uuid, alias: aliasDraft)
        editingUUID = nil
    }
}
