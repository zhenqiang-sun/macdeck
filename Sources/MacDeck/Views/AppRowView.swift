import SwiftUI
import AppKit

struct AppRowView: View {
    let item: WindowLayoutItem
    var onRecord: () -> Void
    var onRestore: () -> Void
    var onRemove: () -> Void

    private var appIcon: NSImage {
        let ws = NSWorkspace.shared
        if let url = ws.urlForApplication(withBundleIdentifier: item.bundleIdentifier) {
            return ws.icon(forFile: url.path)
        }
        return ws.icon(for: .application)
    }

    private var targetDisplayDescription: String {
        if let alias = item.targetDisplayAlias, !alias.isEmpty {
            return alias
        }
        return item.targetDisplayIsMain ? "windowRow.main_screen_badge".localized : "windowRow.sub_screen_badge".localized
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 34, height: 34)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.appName)
                        .font(.system(size: 13, weight: .semibold))

                    if let profile = item.profile {
                        Text(profile)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(4)
                    }

                    if let title = item.windowTitle, !title.isEmpty, title != item.appName {
                        HStack(spacing: 4) {
                            Text(title)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            if item.windowIndex > 0 {
                                Text("#\(item.windowIndex + 1)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                    } else if item.windowIndex > 0 {
                        Text("#\(item.windowIndex + 1)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(3)
                    }
                }

                HStack(spacing: 6) {
                    if item.isRecorded {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DeckTheme.Colors.success)
                                .font(.system(size: 10))
                            Text("windowRow.preset_prefix".localized)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DeckTheme.Colors.success)
                        }

                        Text("【\(targetDisplayDescription)】(\(Int(item.relativeFrame.width))×\(Int(item.relativeFrame.height)))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "circle.dashed")
                                .foregroundColor(DeckTheme.Colors.warning)
                                .font(.system(size: 10))
                            Text("windowRow.current_prefix".localized)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DeckTheme.Colors.warning)
                        }

                        Text("【\(targetDisplayDescription)】(\(Int(item.relativeFrame.width))×\(Int(item.relativeFrame.height))) · \("windowRow.unrecorded_badge".localized)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    if item.isMinimized == true {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 8, weight: .bold))
                            Text("displays.minimized_tag".localized)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DeckTheme.Colors.warning.opacity(0.15))
                        .foregroundColor(DeckTheme.Colors.warning)
                        .cornerRadius(DeckTheme.CornerRadius.badge)
                    } else if item.isFullScreen == true {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 8, weight: .bold))
                            Text("displays.fullscreen_tag".localized)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DeckTheme.Colors.infoBlue.opacity(0.15))
                        .foregroundColor(DeckTheme.Colors.infoBlue)
                        .cornerRadius(DeckTheme.CornerRadius.badge)
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "macwindow")
                                .font(.system(size: 9))
                            Text("windowRow.window_tag".localized)
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DeckTheme.Colors.secondaryFill)
                        .foregroundColor(.secondary)
                        .cornerRadius(DeckTheme.CornerRadius.badge)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onRecord) {
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                        Text("displays.record_button".localized)
                    }
                }
                .deckCompactButton(isProminent: false)

                if item.isRecorded {
                    Button(action: onRestore) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .semibold))
                            Text("displays.restore_button".localized)
                        }
                    }
                    .deckCompactButton(isProminent: true)

                    Button(action: onRemove) {
                        Image(systemName: "trash")
                    }
                    .deckIconButton(size: DeckTheme.ControlHeight.iconCompact, cornerRadius: DeckTheme.CornerRadius.compact, isDestructive: true)
                    .help("displays.remove_help".localized)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DeckTheme.Colors.cardBackground.opacity(0.85))
        .cornerRadius(DeckTheme.CornerRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.card)
                .stroke(DeckTheme.Colors.subtleBorder, lineWidth: 1)
        )
    }
}
