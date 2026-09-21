import SwiftUI

struct SoftwareUpdateView: View {
    @StateObject private var vm = SoftwareUpdateViewModel()
    @ObservedObject private var loc = LocalizationService.shared

    @State private var showClearHistoryAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar (两行优雅布局，彻底消除按钮截断)
            VStack(spacing: 12) {
                // 第一行：标题与主操作按钮
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("update.page_title".localized)
                            .font(.system(size: 18, weight: .bold))
                        Text(headerSubtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Action Buttons (完整文字展示，杜绝截断，高度统一 30pt)
                    HStack(spacing: 8) {
                        if vm.isUpgrading || vm.isChecking || vm.isUninstalling || vm.isScanningInstalled {
                            Button("update.abort".localized, action: vm.cancel)
                                .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button, isDestructive: true)
                        }

                        if vm.currentScope == .updates {
                            Button(action: vm.checkUpdates) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("update.check_available".localized)
                                }
                            }
                            .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                            .disabled(vm.isChecking || vm.isUpgrading)

                            Button(action: vm.upgradeSelected) {
                                HStack(spacing: 5) {
                                    Image(systemName: "bolt.fill")
                                    Text(String(format: "update.upgrade_selected_count".localized, vm.selectedItemsCount))
                                }
                            }
                            .deckPrimaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                            .disabled(vm.selectedItemsCount == 0 || vm.isUpgrading || vm.isChecking)
                        } else if vm.currentScope == .installed {
                            Button(action: vm.scanInstalled) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("update.rescan".localized)
                                }
                            }
                            .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                            .disabled(vm.isScanningInstalled)
                        } else if vm.currentScope == .history {
                            Menu {
                                Button("update.export_json_file".localized) { exportHistoryToFile(format: "json") }
                                Button("update.export_csv_file".localized) { exportHistoryToFile(format: "csv") }
                                Divider()
                                Button("update.copy_json_clipboard".localized) { copyHistoryToClipboard(json: true) }
                                Button("update.copy_csv_clipboard".localized) { copyHistoryToClipboard(json: false) }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("update.export_history".localized)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8))
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
                            .disabled(vm.historyRecords.isEmpty)

                            Button(action: { showClearHistoryAlert = true }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "trash")
                                    Text("update.clear_history_button".localized)
                                }
                            }
                            .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button, isDestructive: true)
                            .disabled(vm.historyRecords.isEmpty)
                        }

                        Button(action: vm.openLogFile) {
                            Image(systemName: "doc.text")
                        }
                        .deckIconButton(size: DeckTheme.ControlHeight.iconRegular, cornerRadius: DeckTheme.CornerRadius.button)
                        .help("update.view_log_file".localized)
                    }
                }

                // 第二行：分类切换选择器 (凹槽底板滑块)
                HStack {
                    DeckSegmentedContainer {
                        ForEach(ViewScope.allCases) { scope in
                            DeckSegmentedItem(
                                title: scopeTitle(for: scope),
                                isSelected: vm.currentScope == scope
                            ) {
                                vm.currentScope = scope
                            }
                        }
                    }
                    .onChange(of: vm.currentScope) { newScope in
                        if newScope == .installed && vm.installedItems.isEmpty {
                            vm.scanInstalled()
                        } else if newScope == .history {
                            vm.loadHistory()
                        }
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()

            if vm.currentScope == .history {
                UpdateHistoryListView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                packagesView
            }

            // Slim Bottom Status & Terminal Console
            TerminalConsoleDrawer(
                isExpanded: $vm.isConsoleExpanded,
                logText: vm.consoleLog,
                statusSummary: vm.statusMessage,
                onClear: { vm.consoleLog = "" }
            )
        }
        .alert(item: $vm.itemToUninstall) { item in
            Alert(
                title: Text(String(format: "update.confirm_uninstall_title".localized, item.displayName)),
                message: Text(String(format: "update.confirm_uninstall_desc".localized, item.source.displayName, item.rawName)),
                primaryButton: .destructive(Text("update.confirm_uninstall_action".localized)) {
                    vm.confirmUninstall()
                },
                secondaryButton: .cancel(Text("common.cancel".localized))
            )
        }
        .alert(isPresented: $vm.showMajorConfirmAlert) {
            let names = vm.majorUpdateItems.map { "• \($0.displayName) (\($0.currentVersion) ➔ \($0.latestVersion))" }.joined(separator: "\n")
            return Alert(
                title: Text("update.major_upgrade_detected".localized),
                message: Text(String(format: "update.major_upgrade_desc".localized, names)),
                primaryButton: .default(Text("update.continue_upgrade".localized)) {
                    vm.confirmMajorUpgrade()
                },
                secondaryButton: .cancel(Text("common.cancel".localized))
            )
        }
        .alert(isPresented: $showClearHistoryAlert) {
            Alert(
                title: Text("update.clear_history_alert_title".localized),
                message: Text("update.clear_history_alert_desc".localized),
                primaryButton: .destructive(Text("update.clear_history_confirm_action".localized)) {
                    vm.clearHistory()
                },
                secondaryButton: .cancel(Text("common.cancel".localized))
            )
        }
    }

    private var packagesView: some View {
        VStack(spacing: 0) {
            // Filter & Search Toolbar
            HStack(spacing: 8) {
                // Category Pills (使用统一底板槽)
                ScrollView(.horizontal, showsIndicators: false) {
                    DeckSegmentedContainer {
                        DeckSegmentedItem(
                            title: "common.all".localized,
                            count: vm.activeList.count,
                            isSelected: vm.selectedFilter == nil
                        ) {
                            vm.selectedFilter = nil
                        }

                        ForEach([PackageSource.brewCask, .brewFormula, .npmGlobal, .volta, .pipx, .cargo, .appStore], id: \.self) { src in
                            let count = vm.activeList.filter { $0.source == src }.count
                            if count > 0 || vm.selectedFilter == src {
                                DeckSegmentedItem(
                                    title: src.displayName,
                                    count: count,
                                    isSelected: vm.selectedFilter == src
                                ) {
                                    vm.selectedFilter = src
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }

                Spacer()

                // Search Box (对齐 28pt 高度与圆角)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("update.search_packages_placeholder".localized, text: $vm.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .frame(minWidth: 120, idealWidth: 150, maxWidth: 200)

                    if !vm.searchQuery.isEmpty {
                        Button(action: { vm.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(DeckTheme.Colors.cardBackground)
                .cornerRadius(DeckTheme.CornerRadius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.button)
                        .stroke(DeckTheme.Colors.subtleBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))

            // Sub-header for Updates Scope (Aligned Select All)
            if vm.currentScope == .updates && !vm.filteredItems.isEmpty {
                Divider()
                HStack(spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { vm.allSelected },
                        set: { _ in vm.toggleSelectAll() }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .frame(width: 18)

                    Text(vm.allSelected ? "update.deselect_all".localized : String(format: "update.select_all_with_count".localized, vm.filteredItems.count))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("update.operations_col".localized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
            }

            Divider()

            // List Area
            if vm.filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: vm.activeList.isEmpty ? (vm.currentScope == .updates ? "arrow.clockwise.circle" : "shippingbox") : "magnifyingglass")
                        .font(.system(size: 34))
                        .foregroundColor(.secondary.opacity(0.45))
                    Text(emptyListMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if vm.activeList.isEmpty {
                        Button(action: {
                            if vm.currentScope == .updates {
                                vm.checkUpdates()
                            } else {
                                vm.scanInstalled()
                            }
                        }) {
                            Text(vm.currentScope == .updates ? "update.click_to_check".localized : "update.click_to_scan_installed".localized)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach($vm.activeList) { $item in
                            if vm.filteredItems.contains(where: { $0.id == item.id }) {
                                PackageRowView(
                                    item: $item,
                                    isUpdatesScope: vm.currentScope == .updates,
                                    onUpgrade: { vm.upgradeSingle(item: item) },
                                    onUninstall: { vm.requestUninstall(item: item) }
                                )
                                Divider()
                                    .padding(.horizontal, 10)
                                    .opacity(0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func exportHistoryToFile(format: String) {
        let savePanel = NSSavePanel()
        savePanel.title = "update.export_history_title".localized
        savePanel.nameFieldStringValue = "macdeck_update_history_\(formattedCurrentDate()).\(format)"
        savePanel.canCreateDirectories = true
        if let window = NSApp.keyWindow {
            savePanel.beginSheetModal(for: window) { response in
                if response == .OK, let url = savePanel.url {
                    let content = format == "json" ? vm.exportHistoryJSON() : vm.exportHistoryCSV()
                    try? content.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        }
    }

    private func copyHistoryToClipboard(json: Bool) {
        let content = json ? vm.exportHistoryJSON() : vm.exportHistoryCSV()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    private func formattedCurrentDate() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        return df.string(from: Date())
    }

    private var headerSubtitle: String {
        switch vm.currentScope {
        case .updates:
            return vm.items.isEmpty ? "update.subtitle_updates_empty".localized : String(format: "update.subtitle_updates_count".localized, vm.items.count)
        case .installed:
            return vm.installedItems.isEmpty ? "update.subtitle_installed_empty".localized : String(format: "update.subtitle_installed_count".localized, vm.installedItems.count)
        case .history:
            return vm.historyRecords.isEmpty ? "update.subtitle_history_empty".localized : String(format: "update.subtitle_history_count".localized, vm.historyRecords.count)
        }
    }

    private func scopeTitle(for scope: ViewScope) -> String {
        switch scope {
        case .updates:
            return vm.items.isEmpty ? "update.scope_updates".localized : "\("update.scope_updates".localized) (\(vm.items.count))"
        case .installed:
            return vm.installedItems.isEmpty ? "update.scope_installed".localized : "\("update.scope_installed".localized) (\(vm.installedItems.count))"
        case .history:
            return vm.historyRecords.isEmpty ? "update.scope_history".localized : "\("update.scope_history".localized) (\(vm.historyRecords.count))"
        }
    }

    private var emptyListMessage: String {
        if vm.activeList.isEmpty {
            return vm.currentScope == .updates ? "update.empty_updates_desc".localized : "update.empty_installed_desc".localized
        } else {
            return "update.empty_no_match".localized
        }
    }
}
