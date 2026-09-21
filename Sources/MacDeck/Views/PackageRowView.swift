import SwiftUI
import AppKit

struct PackageRowView: View {
    @Binding var item: SoftwarePackageItem
    let isUpdatesScope: Bool
    let onUpgrade: () -> Void
    let onUninstall: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox only in Updates scope
            if isUpdatesScope {
                Toggle("", isOn: $item.isSelected)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .disabled(item.status == .upgrading || item.status == .upgraded)
                    .frame(width: 18)
            }

            // Real App Icon or Colored Glyph
            Group {
                if let appIcon = AppIconHelper.icon(for: item) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                        .cornerRadius(5)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(sourceColor.opacity(0.15))
                            .frame(width: 26, height: 26)
                        Image(systemName: item.source.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(sourceColor)
                    }
                }
            }

            // Name & Source
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(item.source.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DeckTheme.Colors.secondaryFill)
                        .foregroundColor(.secondary)
                        .cornerRadius(DeckTheme.CornerRadius.badge)
                }

                // Version display
                if item.hasUpdate {
                    HStack(spacing: 5) {
                        Text(item.currentVersion)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(item.latestVersion)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(DeckTheme.Colors.success)

                        if item.isMajorUpdate {
                            Text("Major")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(DeckTheme.Colors.warning.opacity(0.18))
                                .foregroundColor(DeckTheme.Colors.warning)
                                .cornerRadius(DeckTheme.CornerRadius.badge)
                        }

                        if item.isPinned {
                            Text("update.pinned_badge".localized)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(DeckTheme.Colors.secondaryFill)
                                .foregroundColor(.secondary)
                                .cornerRadius(DeckTheme.CornerRadius.badge)
                        }
                    }
                } else {
                    HStack(spacing: 5) {
                        Text(item.currentVersion == "已安装" ? "update.latest_installed".localized : "v\(item.currentVersion)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)

                        if item.isPinned {
                            Text("update.pinned_badge".localized)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(DeckTheme.Colors.secondaryFill)
                                .foregroundColor(.secondary)
                                .cornerRadius(DeckTheme.CornerRadius.badge)
                        }
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                // If has update available
                if item.hasUpdate {
                    switch item.status {
                    case .available:
                        Button(action: onUpgrade) {
                            Text("update.upgrade_action".localized)
                        }
                        .deckCompactButton(isProminent: true)

                    case .upgrading:
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("update.upgrading_tag".localized)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                    case .upgraded:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DeckTheme.Colors.success)
                            .font(.system(size: 14))

                    case .failed(let message):
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DeckTheme.Colors.danger)
                            .font(.system(size: 14))
                            .help(message)
                    }
                }

                // Uninstall button (in Installed scope)
                if !isUpdatesScope {
                    Button(action: onUninstall) {
                        Image(systemName: "trash")
                    }
                    .deckIconButton(size: DeckTheme.ControlHeight.iconCompact, cornerRadius: DeckTheme.CornerRadius.compact, isDestructive: true)
                    .help("update.uninstall_package_help".localized)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.card)
                .fill(isHovered ? DeckTheme.Colors.cardBackground.opacity(0.8) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            if item.isPinned {
                Button("update.unpin_package".localized) {
                    UpdateSettingsStore.shared.unpin(rawName: item.rawName)
                }
            } else {
                Button("update.pin_package_hint".localized) {
                    UpdateSettingsStore.shared.pinPackage(rawName: item.rawName)
                }
            }

            if item.hasUpdate {
                if item.isIgnored {
                    Button("update.restore_version_alert".localized) {
                        UpdateSettingsStore.shared.unignore(rawName: item.rawName)
                    }
                } else {
                    Button(String(format: "update.ignore_this_version".localized, item.latestVersion)) {
                        UpdateSettingsStore.shared.ignoreVersion(rawName: item.rawName, version: item.latestVersion)
                    }
                }
            }
        }
    }

    private var sourceColor: Color {
        switch item.source {
        case .brewCask: return .blue
        case .brewFormula: return .orange
        case .npmGlobal: return .red
        case .volta: return .yellow
        case .appStore: return .cyan
        case .pipx: return .purple
        case .cargo: return .brown
        }
    }
}
