import SwiftUI

struct HeroMachineCardView: View {
    let report: SystemInfoReport
    @ObservedObject var vm: SystemInfoViewModel

    @State private var copiedSerial = false

    var body: some View {
        HStack(alignment: .center, spacing: DeckTheme.Spacing.lg) {
            // 左侧 Mac 硬件图标
            ZStack {
                RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.outer)
                    .fill(DeckTheme.Colors.accentMuted)
                    .frame(width: 64, height: 64)
                Image(systemName: machineIconName(for: report.modelIdentifier))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(DeckTheme.Colors.accent)
            }

            // 中间规格与状态标识
            VStack(alignment: .leading, spacing: DeckTheme.Spacing.xs) {
                HStack(spacing: DeckTheme.Spacing.sm) {
                    Text(report.machineName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)

                    Text(report.modelIdentifier)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DeckTheme.Colors.trackBackground)
                        .cornerRadius(DeckTheme.CornerRadius.badge)
                        .foregroundColor(.secondary)

                    // FileVault 状态标签
                    HStack(spacing: 3) {
                        Image(systemName: report.security.fileVaultEnabled ? "lock.fill" : "lock.open")
                            .font(.system(size: 10))
                        Text(report.security.fileVaultEnabled ? "sysinfo.filevault_protected".localized : "sysinfo.filevault_unprotected".localized)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(report.security.fileVaultEnabled ? DeckTheme.Colors.success.opacity(0.12) : DeckTheme.Colors.warning.opacity(0.12))
                    .foregroundColor(report.security.fileVaultEnabled ? DeckTheme.Colors.success : DeckTheme.Colors.warning)
                    .cornerRadius(DeckTheme.CornerRadius.badge)
                }

                HStack(spacing: DeckTheme.Spacing.md) {
                    // 序列号与单项复制
                    HStack(spacing: DeckTheme.Spacing.xxs) {
                        Text("\("sysinfo.serial_number".localized):")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(report.serialNumber)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)

                        Button(action: {
                            vm.copySingleItem(title: "sysinfo.serial_number".localized, value: report.serialNumber)
                            copiedSerial = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedSerial = false
                            }
                        }) {
                            Image(systemName: copiedSerial ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(copiedSerial ? DeckTheme.Colors.success : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("sysinfo.copy_serial".localized)
                    }

                    Text("·")
                        .foregroundColor(.secondary)

                    // 登录用户与 Shell
                    HStack(spacing: DeckTheme.Spacing.xxs) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("\(report.security.currentUser) (\(report.security.userShell.components(separatedBy: "/").last ?? "zsh"))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Text("·")
                        .foregroundColor(.secondary)

                    // 运行时间
                    HStack(spacing: DeckTheme.Spacing.xxs) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("\("sysinfo.uptime_prefix".localized): \(report.uptimeString)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Text("·")
                        .foregroundColor(.secondary)

                    // SIP 状态胶囊
                    HStack(spacing: DeckTheme.Spacing.xxs) {
                        Circle()
                            .fill(report.security.sipEnabled ? DeckTheme.Colors.success : DeckTheme.Colors.warning)
                            .frame(width: 6, height: 6)
                        Text("SIP: \(report.security.sipEnabled ? "common.enabled".localized : "common.disabled".localized)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(report.security.sipEnabled ? DeckTheme.Colors.success : DeckTheme.Colors.warning)
                    }
                }
            }

            Spacer()

            // 右侧操作区
            HStack(spacing: DeckTheme.Spacing.sm) {
                Button(action: {
                    vm.copyReport()
                }) {
                    HStack(spacing: DeckTheme.Spacing.xs) {
                        Image(systemName: vm.copyFeedbackMessage != nil ? "checkmark" : "doc.on.doc")
                        Text(vm.copyFeedbackMessage != nil ? "\("common.copied".localized) ✓" : "sysinfo.copy_report_button".localized)
                    }
                }
                .buttonStyle(DeckSecondaryButtonStyle())
                .help("sysinfo.copy_report_help".localized)

                Button(action: {
                    vm.refresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(DeckIconButtonStyle())
                .help("sysinfo.refresh_help".localized)
            }
        }
        .padding(DeckTheme.Spacing.lg)
        .background(DeckTheme.Colors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.outer)
                .stroke(DeckTheme.Colors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(DeckTheme.CornerRadius.outer)
    }

    private func machineIconName(for identifier: String) -> String {
        if identifier.contains("MacBook") || identifier.hasPrefix("Mac14,") || identifier.hasPrefix("Mac15,") {
            return "laptopcomputer"
        } else if identifier.contains("Macmini") {
            return "macmini"
        } else if identifier.contains("MacStudio") {
            return "macstudio"
        } else if identifier.contains("MacPro") {
            return "macpro.gen3"
        } else if identifier.contains("iMac") {
            return "desktopcomputer"
        }
        return "laptopcomputer"
    }
}

