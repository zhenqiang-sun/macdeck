import SwiftUI

struct TerminalConsoleDrawer: View {
    @Binding var isExpanded: Bool
    let logText: String
    let statusSummary: String
    let onClear: () -> Void

    @State private var copiedToast: Bool = false

    private var logLines: [String] {
        logText.components(separatedBy: .newlines)
    }

    private var indicatorColor: Color {
        if logText.isEmpty {
            return Color.secondary.opacity(0.4)
        }
        let lower = logText.lowercased()
        if lower.contains("error") || lower.contains("failed") || logText.contains("✗") || logText.contains("✖") {
            return DeckTheme.Colors.danger
        }
        if lower.contains("warning") || logText.contains("⚠️") || logText.contains("!") {
            return DeckTheme.Colors.warning
        }
        return DeckTheme.Colors.success
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Slim Bottom Status & Toggle Bar
            HStack(spacing: 8) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 6, height: 6)

                Text(statusSummary)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 9, weight: .bold))
                        Text(isExpanded ? "terminal.collapse_console".localized : "terminal.expand_console".localized)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(DeckTheme.Colors.accent)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()
                        .frame(height: 12)

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(logText, forType: .string)
                        copiedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedToast = false
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: copiedToast ? "checkmark" : "doc.on.doc")
                            Text(copiedToast ? "common.copied".localized : "common.copy".localized)
                        }
                    }
                    .deckCompactButton(isProminent: false, color: copiedToast ? DeckTheme.Colors.success : nil)
                    .disabled(logText.isEmpty)

                    Button("terminal.clear_log".localized, action: onClear)
                        .deckCompactButton(isProminent: false)
                        .disabled(logText.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Color(NSColor.windowBackgroundColor))

            // Expanded Terminal Body (Native NSTextView for full text selection and copying)
            if isExpanded {
                ConsoleLogTextView(text: logText)
                    .frame(height: 140)
                    .background(Color(red: 0.09, green: 0.10, blue: 0.12))
                    .cornerRadius(DeckTheme.CornerRadius.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.card)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Native AppKit Console Log Text View (Selectable & Performant)

struct ConsoleLogTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.drawsBackground = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        scrollView.documentView = textView
        context.coordinator.textView = textView

        updateAttributedText(textView: textView, text: text)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if context.coordinator.lastText != text {
            context.coordinator.lastText = text
            updateAttributedText(textView: textView, text: text)
            if textView.selectedRange().length == 0 {
                DispatchQueue.main.async {
                    textView.scrollToEndOfDocument(nil)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        weak var textView: NSTextView?
        var lastText: String = ""
    }

    private func updateAttributedText(textView: NSTextView, text: String) {
        if text.isEmpty {
            let placeholder = NSAttributedString(
                string: "terminal.empty_log".localized,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.4)
                ]
            )
            textView.textStorage?.setAttributedString(placeholder)
            return
        }

        let attrString = NSMutableAttributedString()
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let color = nsColorForLine(line)
            let lineStr = index < lines.count - 1 ? line + "\n" : line
            let lineAttr = NSAttributedString(
                string: lineStr,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: color
                ]
            )
            attrString.append(lineAttr)
        }
        textView.textStorage?.setAttributedString(attrString)
    }

    private func nsColorForLine(_ line: String) -> NSColor {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("==>") {
            return NSColor(red: 0.35, green: 0.75, blue: 1.0, alpha: 1.0)
        } else if trimmed.hasPrefix("✓") || trimmed.hasPrefix("✔") || trimmed.hasPrefix("✅") {
            return NSColor(red: 0.30, green: 0.88, blue: 0.45, alpha: 1.0)
        } else if trimmed.hasPrefix("✗") || trimmed.hasPrefix("✖") || trimmed.contains("FAILED") || trimmed.contains("Error") {
            return NSColor(red: 1.0, green: 0.40, blue: 0.40, alpha: 1.0)
        } else if trimmed.hasPrefix("!") || trimmed.contains("Warning") {
            return NSColor(red: 1.0, green: 0.82, blue: 0.28, alpha: 1.0)
        } else if trimmed.hasPrefix("$ ") {
            return NSColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 1.0)
        } else {
            return NSColor(red: 0.88, green: 0.90, blue: 0.93, alpha: 1.0)
        }
    }
}
