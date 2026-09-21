import SwiftUI

struct UpdateHistoryListView: View {
    @ObservedObject var vm: SoftwareUpdateViewModel
    @ObservedObject private var loc = LocalizationService.shared

    var body: some View {
        VStack(spacing: 0) {
            // History Filter Bar
            HStack(spacing: DeckTheme.Spacing.md) {
                // Status Filter Track
                DeckSegmentedContainer {
                    DeckSegmentedItem(
                        title: "update.all_statuses".localized,
                        isSelected: vm.historyStatusFilter == nil
                    ) {
                        vm.historyStatusFilter = nil
                    }
                    DeckSegmentedItem(
                        title: "update.status_success".localized,
                        isSelected: vm.historyStatusFilter == .success
                    ) {
                        vm.historyStatusFilter = .success
                    }
                    DeckSegmentedItem(
                        title: "update.status_failed".localized,
                        isSelected: vm.historyStatusFilter == .failed
                    ) {
                        vm.historyStatusFilter = .failed
                    }
                }

                Divider()
                    .frame(height: 16)

                // Search Bar
                HStack(spacing: DeckTheme.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("update.search_history_placeholder".localized, text: $vm.historySearchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                    if !vm.historySearchQuery.isEmpty {
                        Button(action: { vm.historySearchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DeckTheme.Spacing.sm)
                .frame(height: 28)
                .background(DeckTheme.Colors.cardBackground)
                .cornerRadius(DeckTheme.CornerRadius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.button)
                        .stroke(DeckTheme.Colors.cardBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Records List
            if vm.filteredHistoryRecords.isEmpty {
                emptyHistoryView
            } else {
                ScrollView {
                    LazyVStack(spacing: DeckTheme.Spacing.sm) {
                        ForEach(vm.filteredHistoryRecords) { record in
                            UpdateHistoryRowView(record: record)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var emptyHistoryView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 38))
                .foregroundColor(.secondary.opacity(0.6))

            Text(vm.historyRecords.isEmpty ? "update.empty_history_title".localized : "update.empty_history_no_match".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            if vm.historyRecords.isEmpty {
                Text("update.empty_history_desc".localized)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
