import SwiftUI
import AppKit

struct EnvironmentMaintenanceView: View {
    @StateObject private var vm = EnvironmentMaintenanceViewModel()
    @ObservedObject private var loc = LocalizationService.shared
    @State private var expandedDoctorIds: Set<String> = []
    @State private var copiedFixId: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerView
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    doctorSection
                    cleanupSection
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Slim Bottom Status & Terminal Console
            TerminalConsoleDrawer(
                isExpanded: $vm.isConsoleExpanded,
                logText: vm.consoleLog,
                statusSummary: vm.statusMessage,
                onClear: { vm.consoleLog = "" }
            )
        }
        .alert(isPresented: $vm.showCleanConfirmationAlert) {
            cleanConfirmationAlert
        }
        .onAppear {
            if vm.doctorItems.isEmpty {
                vm.runDiagnosis()
            }
            vm.scanCacheSizes()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("doctor.header_title".localized)
                        .font(.system(size: 18, weight: .bold))

                    healthBadge
                    cleanableBadge
                }

                Text("doctor.header_subtitle".localized)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    vm.runDiagnosis()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                        Text("doctor.run_diagnosis".localized)
                    }
                }
                .deckSecondaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button)
                .disabled(vm.isDiagnosing)

                Button(action: {
                    vm.requestClean(target: .all)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                        Text("doctor.clean_all".localized)
                    }
                }
                .deckPrimaryButton(height: DeckTheme.ControlHeight.regular, cornerRadius: DeckTheme.CornerRadius.button, color: DeckTheme.Colors.danger)
                .disabled(vm.totalCleanableBytes == 0 || vm.isCleaning)
            }
        }
    }

    private var healthBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: vm.overallHealth.iconName)
                .font(.system(size: 10, weight: .bold))
            Text(healthText(for: vm.overallHealth))
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(healthBadgeColor.opacity(0.12))
        .foregroundColor(healthBadgeColor)
        .cornerRadius(DeckTheme.CornerRadius.badge)
    }

    private func healthText(for status: HealthStatus) -> String {
        switch status {
        case .healthy: return "doctor.status_healthy".localized
        case .warning: return "doctor.status_warning".localized
        case .error: return "doctor.status_error".localized
        case .notInstalled: return "common.disabled".localized
        }
    }

    private var healthBadgeColor: Color {
        switch vm.overallHealth {
        case .healthy: return DeckTheme.Colors.success
        case .warning: return DeckTheme.Colors.warning
        case .error: return DeckTheme.Colors.danger
        case .notInstalled: return .secondary
        }
    }

    private var cleanableBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive")
                .font(.system(size: 10))
            Text(String(format: "doctor.reclaimable_badge".localized, vm.formattedTotalCleanable))
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(DeckTheme.Colors.accent.opacity(0.12))
        .foregroundColor(DeckTheme.Colors.accent)
        .cornerRadius(DeckTheme.CornerRadius.badge)
    }

    // MARK: - Doctor Section

    private var doctorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("doctor.section_doctor_title".localized)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                if vm.isDiagnosing {
                    ProgressView()
                        .scaleEffect(0.65)
                        .padding(.trailing, 4)
                    Text("doctor.diagnosing_status".localized)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            if vm.doctorItems.isEmpty && !vm.isDiagnosing {
                HStack {
                    Spacer()
                    Text("doctor.no_items_hint".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(20)
                    Spacer()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(vm.doctorItems) { item in
                        doctorItemRow(item)
                    }
                }
            }
        }
    }

    private func doctorItemRow(_ item: DoctorItem) -> some View {
        let isExpanded = expandedDoctorIds.contains(item.id)
        let hasDetails = !item.details.isEmpty || item.fixCommand != nil

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: item.status.iconName)
                    .font(.system(size: 15))
                    .foregroundColor(colorForStatus(item.status))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))

                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(item.summary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if hasDetails {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if isExpanded {
                                expandedDoctorIds.remove(item.id)
                            } else {
                                expandedDoctorIds.insert(item.id)
                            }
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text(isExpanded ? "doctor.collapse".localized : "doctor.details".localized)
                                .font(.system(size: 11))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if isExpanded && hasDetails {
                Divider()
                    .padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(item.details, id: \.self) { detail in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(detail)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                    }

                    if let fix = item.fixCommand {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 11))

                            Text("doctor.suggested_fix".localized)
                                .font(.system(size: 11, weight: .medium))

                            Text(fix)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.15))
                                .cornerRadius(4)
                                .textSelection(.enabled)

                            Spacer()

                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(fix, forType: .string)
                                copiedFixId = item.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    if copiedFixId == item.id { copiedFixId = nil }
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: copiedFixId == item.id ? "checkmark" : "doc.on.doc")
                                    Text(copiedFixId == item.id ? "common.copied".localized : "doctor.copy_command".localized)
                                }
                                .font(.system(size: 10))
                                .foregroundColor(copiedFixId == item.id ? .green : .accentColor)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func colorForStatus(_ status: HealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .warning: return .orange
        case .error: return .red
        case .notInstalled: return .secondary.opacity(0.6)
        }
    }

    // MARK: - Cleanup Section

    private var cleanupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("doctor.section_cleanup_title".localized)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: {
                    vm.scanCacheSizes()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                        Text("doctor.refresh_caches".localized)
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(vm.cleanupItems) { item in
                    cleanupItemCard(item)
                }
            }
        }
    }

    private func cleanupItemCard(_ item: CleanupItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text(item.formattedSize)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(item.sizeBytes > 0 ? .primary : .secondary)
            }

            Text(item.pathDescription)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)

            HStack {
                Spacer()

                Button("doctor.clean_button".localized) {
                    vm.requestClean(target: .single(item))
                }
                .deckCompactButton(isProminent: false)
                .disabled(item.sizeBytes == 0 || vm.isCleaning)
            }
        }
        .padding(14)
        .background(DeckTheme.Colors.cardBackground.opacity(0.85))
        .cornerRadius(DeckTheme.CornerRadius.outer)
        .overlay(
            RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.outer)
                .stroke(DeckTheme.Colors.subtleBorder, lineWidth: 1)
        )
    }

    // MARK: - Confirmation Alert

    private var cleanConfirmationAlert: Alert {
        let title: String
        let message: String
        switch vm.pendingCleanTarget {
        case .all:
            title = "doctor.clean_all_confirm_title".localized
            message = String(format: "doctor.clean_all_confirm_desc".localized, vm.formattedTotalCleanable)
        case .single(let item):
            title = String(format: "doctor.clean_single_confirm_title".localized, item.name)
            message = String(format: "doctor.clean_single_confirm_desc".localized, item.pathDescription, item.formattedSize)
        }

        return Alert(
            title: Text(title),
            message: Text(message),
            primaryButton: .destructive(Text("doctor.clean_now".localized)) {
                vm.confirmClean()
            },
            secondaryButton: .cancel(Text("common.cancel".localized))
        )
    }
}
