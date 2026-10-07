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

            Section(header: Text("settings.restoration_section".localized).font(.system(size: 13, weight: .semibold))) {
                Toggle("settings.auto_restore_on_match".localized, isOn: Binding(
                    get: { state.autoRestoreOnProfileMatch },
                    set: { state.updateAutoRestoreOnProfileMatch($0) }
                ))
                Text("settings.auto_restore_desc".localized)
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

            Section(header: Text("settings.software_update_section".localized).font(.system(size: 13, weight: .semibold))) {
                Toggle("settings.auto_check_updates".localized, isOn: $autoCheckEnabled)
                    .onChange(of: autoCheckEnabled) { newValue in
                        UpdateSettingsStore.shared.setAutoCheckEnabled(newValue)
                    }
                Text("settings.auto_check_desc".localized)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if autoCheckEnabled {
                    Picker("settings.check_interval".localized, selection: $checkIntervalHours) {
                        Text("settings.every_12_hours".localized).tag(12)
                        Text("settings.every_24_hours".localized).tag(24)
                        Text("settings.every_48_hours".localized).tag(48)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: checkIntervalHours) { newValue in
                        UpdateSettingsStore.shared.setCheckIntervalHours(newValue)
                    }
                }
            }

            Section(header: Text("settings.shortcuts_section".localized).font(.system(size: 13, weight: .semibold))) {
                HStack {
                    HStack(spacing: 4) {
                        KeycapBadge(text: "⌘")
                        Text("+")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        KeycapBadge(text: "Return")
                    }
                    Spacer()
                    Text("settings.shortcut_restore_all".localized)
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
                    Text("settings.shortcut_snapshot".localized)
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
                    Text("settings.shortcut_quit".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("settings.config_path_section".localized).font(.system(size: 13, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.config_path_label".localized)
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
                                Text(copiedPath ? "common.copied".localized : "common.copy_path".localized)
                            }
                        }
                        .deckCompactButton(isProminent: false)

                        Button("common.open_in_finder".localized) {
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
                            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.1"
                            Text("v\(appVersion)")
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
                        Text("settings.app_description".localized)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: {
                            if let url = URL(string: "https://macdeck-app.vercel.app") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "safari")
                                Text("settings.website".localized)
                            }
                        }
                        .deckCompactButton(isProminent: false)

                        Button(action: {
                            if let url = URL(string: "https://github.com/zhenqiang-sun/macdeck") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "star")
                                Text("GitHub")
                            }
                        }
                        .deckCompactButton(isProminent: false)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
