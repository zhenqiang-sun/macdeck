import SwiftUI

struct PermissionBannerView: View {
    var onRequestPermission: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DeckTheme.Colors.warning)
                .font(.system(size: 15))
            Text("permission.banner_desc".localized)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            Button("permission.grant_button".localized) {
                onRequestPermission()
            }
            .deckCompactButton(isProminent: true, color: DeckTheme.Colors.warning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(DeckTheme.Colors.warning.opacity(0.12))
        .cornerRadius(DeckTheme.CornerRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.card)
                .stroke(DeckTheme.Colors.warning.opacity(0.25), lineWidth: 1)
        )
    }
}
