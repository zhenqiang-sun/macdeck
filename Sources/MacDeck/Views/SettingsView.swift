import SwiftUI
import AppKit

struct KeycapBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(DeckTheme.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.badge)
                    .stroke(DeckTheme.Colors.controlBorder, lineWidth: 1)
            )
            .cornerRadius(DeckTheme.CornerRadius.badge)
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var loc = LocalizationService.shared
    @State private var autoCheckEnabled: Bool = UpdateSettingsStore.shared.autoCheckEnabled
    @State private var checkIntervalHours: Int = UpdateSettingsStore.shared.checkIntervalHours
    @State private var copiedPath: Bool = false

    var body: some View {
        Form {
            Section(header: Text("settings.language_section".localized).font(.system(size: 13, weight: .semibold))) {
                Picker("settings.language_label".localized, selection: Binding(
                    get: { loc.selectedLanguage },
                    set: { loc.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text(loc.effectiveLanguage == .zhHans ? "归位与感知行为" : "Restoration & Sensor Behavior").font(.system(size: 13, weight: .semibold))) {
                Toggle(loc.effectiveLanguage == .zhHans ? "检测到屏幕拓扑匹配时自动一键归位" : "Auto-restore windows when display topology matches", isOn: Binding(
                    get: { state.autoRestoreOnProfileMatch },
                    set: { state.updateAutoRestoreOnProfileMatch($0) }
                ))
                Text(loc.effectiveLanguage == .zhHans ? "开启后，当插拔外接显示器且屏幕硬件组合匹配到已有方案时，系统将在拓扑稳定 1.0 秒后自动执行窗口归位。" : "Automatically restores windows 1.0s after display topology stabilizes upon connecting/disconnecting monitors.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Toggle("settings.auto_quit_label".localized, isOn: Binding(
                    get: { state.autoQuitAfterRestore },
                    set: { state.updateAutoQuit($0) }
                ))
                Text("settings.auto_quit_desc".localized)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Section(header: Text("软件与环境更新").font(.system(size: 13, weight: .semibold))) {
                Toggle("后台自动检查更新", isOn: $autoCheckEnabled)
                    .onChange(of: autoCheckEnabled) { newValue in
                        UpdateSettingsStore.shared.setAutoCheckEnabled(newValue)
                    }
                Text("开启后，MacDeck 会在启动后及周期性静默检测可用软件更新，并通过侧边栏角标提醒。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if autoCheckEnabled {
                    Picker("检查频率", selection: $checkIntervalHours) {
                        Text("每 12 小时").tag(12)
                        Text("每 24 小时 (推荐)").tag(24)
                        Text("每 48 小时").tag(48)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: checkIntervalHours) { newValue in
                        UpdateSettingsStore.shared.setCheckIntervalHours(newValue)
                    }
                }
            }

            Section(header: Text("快捷键指南").font(.system(size: 13, weight: .semibold))) {
                HStack {
                    HStack(spacing: 4) {
                        KeycapBadge(text: "⌘")
                        Text("+")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        KeycapBadge(text: "Return")
                    }
                    Spacer()
                    Text("触发全部窗口一键归位")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                HStack {
                    HStack(spacing: 4) {
                        KeycapBadge(text: "⌘")
                        Text("+")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        KeycapBadge(text: "S")
                    }
                    Spacer()
                    Text("快照保存当前所有窗口布局至当前方案")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                HStack {
                    HStack(spacing: 4) {
                        KeycapBadge(text: "⌘")
                        Text("+")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        KeycapBadge(text: "Q")
                    }
                    Spacer()
                    Text("退出 MacDeck")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("数据与配置").font(.system(size: 13, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("配置文件存储路径:")
                        .font(.system(size: 12))

                    HStack {
                        Text("~/.config/macdeck/layouts.json")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, DeckTheme.Spacing.sm)
                            .padding(.vertical, 4)
                            .background(DeckTheme.Colors.accentMuted)
                            .cornerRadius(DeckTheme.CornerRadius.compact)

                        Spacer()

                        Button(action: {
                            let path = NSString(string: "~/.config/macdeck/layouts.json").expandingTildeInPath
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(path, forType: .string)
                            copiedPath = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedPath = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: copiedPath ? "checkmark" : "doc.on.doc")
                                Text(copiedPath ? "已复制" : "复制路径")
                            }
                        }
                        .deckCompactButton(isProminent: false)

                        Button("在访达中显示") {
                            let dirPath = NSString(string: "~/.config/macdeck").expandingTildeInPath
                            let filePath = (dirPath as NSString).appendingPathComponent("layouts.json")
                            let fm = FileManager.default
                            if !fm.fileExists(atPath: dirPath) {
                                try? fm.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
                            }
                            if fm.fileExists(atPath: filePath) {
                                NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: dirPath)
                            } else {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dirPath)
                            }
                        }
                        .deckCompactButton(isProminent: false)
                    }
                }
                .padding(.vertical, 2)
            }

            Section(header: Text("settings.about_section".localized).font(.system(size: 13, weight: .semibold))) {
                HStack(spacing: 12) {
                    Image(systemName: "display.2")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                        .frame(width: 36, height: 36)
                        .background(DeckTheme.Colors.accentMuted)
                        .cornerRadius(DeckTheme.CornerRadius.card)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("MacDeck")
                                .font(.system(size: 13, weight: .bold))
                            Text("v1.1.0")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(DeckTheme.Colors.cardBackground)
                                .cornerRadius(DeckTheme.CornerRadius.badge)

                            Text("GPL-3.0")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(DeckTheme.Colors.accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(DeckTheme.Colors.accentMuted)
                                .cornerRadius(DeckTheme.CornerRadius.badge)
                        }
                        Text(loc.effectiveLanguage == .zhHans ? "macOS 多屏窗口记忆、外接拓扑归位与开发者环境维护套件" : "Native macOS multi-display window restoration & developer environment toolset")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
