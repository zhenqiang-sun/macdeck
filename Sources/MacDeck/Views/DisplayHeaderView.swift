import SwiftUI

struct DisplayHeaderView: View {
    let displays: [DisplayInfo]

    var body: some View {
        HStack(spacing: DeckTheme.Spacing.sm) {
            Image(systemName: "display.2")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
            Text(String(format: "displays.displays_count".localized, displays.count))
                .font(.system(size: 12, weight: .semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DeckTheme.Spacing.xs) {
                    ForEach(displays) { d in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(d.isMain ? DeckTheme.Colors.success : DeckTheme.Colors.infoBlue)
                                .frame(width: 6, height: 6)
                            Text("\(d.displayName) (\(Int(d.boundsWidth))×\(Int(d.boundsHeight)))")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, DeckTheme.Spacing.xs)
                        .padding(.vertical, 3)
                        .background(DeckTheme.Colors.cardBackground)
                        .cornerRadius(DeckTheme.CornerRadius.badge)
                    }
                }
            }
        }
    }
}
