import SwiftUI
import AppKit

struct UpdateHistoryRowView: View {
    let record: UpdateHistoryRecord
    @State private var isExpanded: Bool = false
    @State private var copiedHint: Bool = false
    @State private var copiedCommand: Bool = false

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Row Content
            HStack(alignment: .center, spacing: 12) {
                // Status Icon
                Image(systemName: record.status == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(record.status == .success ? DeckTheme.Colors.success : DeckTheme.Colors.danger)
                    .frame(width: 18)

                // Package Icon & Info
                Image(systemName: record.source.icon)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(record.packageName)
                            .font(.system(size: 13, weight: .semibold))

                        Text(record.source.displayName)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(DeckTheme.Colors.secondaryFill)
                            .foregroundColor(.secondary)
                            .cornerRadius(DeckTheme.CornerRadius.badge)
                    }

                    HStack(spacing: 4) {
                        Text(record.previousVersion)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))

                        Text(record.targetVersion)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(record.status == .success ? .primary : DeckTheme.Colors.danger)
                    }
                }

                Spacer()

                // Timestamp
                Text(Self.dateFormatter.string(from: record.timestamp))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                // Expand/Collapse Chevron
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Expanded Detail View
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    // Command Box
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("update.executed_command".localized)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: copyCommand) {
                                Label(copiedCommand ? "common.copied".localized : "doctor.copy_command".localized, systemImage: copiedCommand ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 10))
                            }
                            .deckCompactButton(isProminent: false, color: copiedCommand ? DeckTheme.Colors.success : nil)
                        }

                        Text(record.command)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(DeckTheme.CornerRadius.compact)
                    }

                    // Rollback Hint (if available)
                    if let hint = record.rollbackHint {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label("update.rollback_hint".localized, systemImage: "arrow.uturn.backward.circle")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DeckTheme.Colors.warning)
                                Spacer()
                                Button(action: copyRollbackHint) {
                                    Label(copiedHint ? "common.copied".localized : "update.copy_rollback_command".localized, systemImage: copiedHint ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 10))
                                }
                                .deckCompactButton(isProminent: false, color: copiedHint ? DeckTheme.Colors.success : nil)
                            }

                            Text(hint)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DeckTheme.Colors.warning.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.compact)
                                        .stroke(DeckTheme.Colors.warning.opacity(0.25), lineWidth: 1)
                                )
                                .cornerRadius(DeckTheme.CornerRadius.compact)
                        }
                    }

                    // Log Output (AppKit selectable text)
                    if !record.outputLog.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("update.output_log".localized)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            ConsoleLogTextView(text: record.outputLog)
                                .frame(minHeight: 80, maxHeight: 160)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(DeckTheme.CornerRadius.compact)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.compact)
                                        .stroke(DeckTheme.Colors.subtleBorder, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .background(DeckTheme.Colors.cardBackground.opacity(0.35))
            }
        }
        .background(DeckTheme.Colors.cardBackground)
        .cornerRadius(DeckTheme.CornerRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.card)
                .stroke(DeckTheme.Colors.subtleBorder, lineWidth: 1)
        )
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.command, forType: .string)
        copiedCommand = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedCommand = false
        }
    }

    private func copyRollbackHint() {
        guard let hint = record.rollbackHint else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hint, forType: .string)
        copiedHint = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedHint = false
        }
    }
}
