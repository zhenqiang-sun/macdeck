import SwiftUI

// MARK: - 通用卡片容器
struct BentoCardContainer<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DeckTheme.Spacing.md) {
            HStack(spacing: DeckTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            content()
        }
        .padding(DeckTheme.Spacing.md)
        .background(DeckTheme.Colors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.outer)
                .stroke(DeckTheme.Colors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(DeckTheme.CornerRadius.outer)
    }
}

// MARK: - 1. Apple Silicon SoC 芯片与统一内存卡片
struct SoCCardView: View {
    let report: SystemInfoReport

    var body: some View {
        BentoCardContainer(title: "sysinfo.soc_title".localized, icon: "cpu.fill", iconColor: DeckTheme.Colors.infoBlue) {
            VStack(alignment: .leading, spacing: DeckTheme.Spacing.sm) {
                // 芯片名与架构
                HStack(alignment: .firstTextBaseline) {
                    Text(report.processor.chipName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    Text(report.processor.architecture)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DeckTheme.Colors.trackBackground)
                        .cornerRadius(DeckTheme.CornerRadius.badge)
                        .foregroundColor(.secondary)
                }

                // CPU 核心构成
                HStack(spacing: DeckTheme.Spacing.xs) {
                    Image(systemName: "circle.grid.cross.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if report.processor.efficiencyCores > 0 {
                        Text(String(format: "sysinfo.cores_detailed".localized, report.processor.totalCPUCores, report.processor.performanceCores, report.processor.efficiencyCores))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: "sysinfo.cores_physical".localized, report.processor.totalCPUCores))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                // GPU 与 NPU
                HStack(spacing: DeckTheme.Spacing.md) {
                    if let gpu = report.processor.gpuCores {
                        HStack(spacing: DeckTheme.Spacing.xxs) {
                            Image(systemName: "display")
                                .font(.system(size: 11))
                                .foregroundColor(DeckTheme.Colors.purple)
                            Text(String(format: "sysinfo.gpu_cores_detailed".localized, gpu))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }

                    HStack(spacing: DeckTheme.Spacing.xxs) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 11))
                            .foregroundColor(DeckTheme.Colors.accent)
                        Text(report.processor.neuralEngine)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }

                Divider()
                    .padding(.vertical, 1)

                // 统一内存架构 (UMA)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DeckTheme.Spacing.xs) {
                        Image(systemName: "memorychip.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DeckTheme.Colors.purple)
                        Text(report.formattedMemory)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)

                        Text("sysinfo.uma_badge".localized)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(DeckTheme.Colors.purple.opacity(0.12))
                            .foregroundColor(DeckTheme.Colors.purple)
                            .cornerRadius(3)
                    }

                    Text("sysinfo.uma_description".localized)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // 高速缓存
                if report.processor.l1DataCache != nil || report.processor.l2Cache != nil {
                    HStack(spacing: DeckTheme.Spacing.md) {
                        if let l1 = report.processor.l1DataCache {
                            Text("L1: \(l1)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        if let l2 = report.processor.l2Cache {
                            Text("L2: \(l2)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 1)
                }
            }
        }
    }
}

// MARK: - 2. 操作系统与安全卡片
struct OSCardView: View {
    let report: SystemInfoReport

    var body: some View {
        BentoCardContainer(title: "sysinfo.os_security_title".localized, icon: "apple.logo", iconColor: .primary) {
            VStack(alignment: .leading, spacing: DeckTheme.Spacing.xs) {
                HStack {
                    Text("\(report.osName) \(report.osVersion)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    Text("Build \(report.osBuildNumber)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Text(report.darwinKernel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                Divider()
                    .padding(.vertical, 2)

                // 安全启动与 Gatekeeper
                HStack(spacing: DeckTheme.Spacing.md) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DeckTheme.Colors.success)
                        Text(report.security.secureBootStatus)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: report.security.gatekeeperEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(report.security.gatekeeperEnabled ? DeckTheme.Colors.success : DeckTheme.Colors.warning)
                        Text("Gatekeeper \(report.security.gatekeeperEnabled ? "common.enabled".localized : "common.disabled".localized)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                // 主目录
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(report.security.userHomeDirectory)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - 3. 统一内存卡片
struct MemoryCardView: View {
    let report: SystemInfoReport

    var body: some View {
        BentoCardContainer(title: "sysinfo.unified_memory".localized, icon: "memorychip.fill", iconColor: DeckTheme.Colors.purple) {
            VStack(alignment: .leading, spacing: DeckTheme.Spacing.xs) {
                Text(report.formattedMemory)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                Text("sysinfo.uma_badge".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Text("sysinfo.uma_description".localized)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, DeckTheme.Spacing.xxs)
            }
        }
    }
}

// MARK: - 4. 存储与多卷卡片
struct StorageCardView: View {
    let report: SystemInfoReport

    var body: some View {
        BentoCardContainer(title: "sysinfo.storage_title".localized, icon: "internaldrive.fill", iconColor: DeckTheme.Colors.accent) {
            VStack(alignment: .leading, spacing: DeckTheme.Spacing.sm) {
                // 内置卷列表
                ForEach(report.internalVolumes) { vol in
                    volumeRow(vol: vol, isInternal: true)
                }

                // 外接磁盘/移动设备列表
                if !report.externalVolumes.isEmpty {
                    Divider()
                        .padding(.vertical, 2)

                    HStack(spacing: 4) {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DeckTheme.Colors.infoBlue)
                        Text("sysinfo.external_storage".localized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    ForEach(report.externalVolumes) { vol in
                        volumeRow(vol: vol, isInternal: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func volumeRow(vol: StorageVolumeInfo, isInternal: Bool) -> some View {
        let level = DiskWatermarkLevel.evaluate(ratio: vol.usageRatio)
        let watermarkColor: Color = {
            switch level {
            case .healthy: return DeckTheme.Colors.success
            case .warning: return DeckTheme.Colors.warning
            case .danger: return DeckTheme.Colors.danger
            }
        }()

        VStack(alignment: .leading, spacing: 3) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: isInternal ? "internaldrive" : "externaldrive")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(vol.name)
                        .font(.system(size: 13, weight: .bold))
                }
                Spacer()
                Text(vol.fileSystem)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(DeckTheme.Colors.trackBackground)
                    .cornerRadius(3)
                    .foregroundColor(.secondary)
            }

            // 水位进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DeckTheme.Colors.trackBackground)
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(watermarkColor)
                        .frame(width: max(4, geo.size.width * CGFloat(min(1.0, vol.usageRatio))), height: 5)
                }
            }
            .frame(height: 5)
            .padding(.vertical, 2)

            HStack {
                Text(String(format: "sysinfo.storage_used_ratio".localized, SystemInfoReport.formatBytes(vol.usedBytes), SystemInfoReport.formatBytes(vol.totalBytes), Int(vol.usageRatio * 100)))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "sysinfo.storage_available".localized, SystemInfoReport.formatBytes(vol.availableBytes)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(watermarkColor)
            }
        }
    }
}

// MARK: - 5. 电池与电源卡片
struct BatteryCardView: View {
    let report: SystemInfoReport

    var body: some View {
        BentoCardContainer(title: "sysinfo.battery_title".localized, icon: "battery.100.bolt", iconColor: DeckTheme.Colors.success) {
            VStack(alignment: .leading, spacing: DeckTheme.Spacing.xs) {
                if let battery = report.batteryInfo {
                    HStack(spacing: DeckTheme.Spacing.xs) {
                        Text("\(battery.currentPercentage)%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)

                        Text(battery.isCharging ? "sysinfo.battery_charging".localized : (battery.isACPowered ? "sysinfo.battery_ac".localized : "sysinfo.battery_on_battery".localized))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(battery.isCharging ? DeckTheme.Colors.success : .secondary)

                        if let watts = battery.chargingWattage, watts > 0 {
                            Text("(\(watts) W)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(DeckTheme.Colors.success.opacity(0.15))
                                .foregroundColor(DeckTheme.Colors.success)
                                .cornerRadius(DeckTheme.CornerRadius.badge)
                        }
                    }

                    HStack(spacing: DeckTheme.Spacing.md) {
                        if let health = battery.healthPercentage {
                            Text(String(format: "sysinfo.battery_health_format".localized, health))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        if let cycles = battery.cycleCount {
                            Text(String(format: "sysinfo.battery_cycles_format".localized, cycles))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(battery.isACPowered ? "sysinfo.battery_adapter_external".localized : "sysinfo.battery_internal".localized)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, DeckTheme.Spacing.xxs)
                } else {
                    Text("sysinfo.battery_desktop_mac".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    Text("sysinfo.battery_desktop_desc".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - 6. 网络与接口卡片
struct NetworkCardView: View {
    let report: SystemInfoReport
    @ObservedObject var vm: SystemInfoViewModel

    @State private var copiedItemKey: String? = nil

    var body: some View {
        BentoCardContainer(title: "sysinfo.network_title".localized, icon: "network", iconColor: DeckTheme.Colors.infoBlue) {
            VStack(alignment: .leading, spacing: DeckTheme.Spacing.xs) {
                // Wi-Fi 射频详情
                if let wifi = report.network.wifiInfo {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: DeckTheme.Spacing.xs) {
                            Image(systemName: "wifi")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DeckTheme.Colors.infoBlue)
                            Text(wifi.ssid)
                                .font(.system(size: 13, weight: .bold))

                            Spacer()

                            // RSSI 信号色标
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(rssiColor(wifi.rssi))
                                    .frame(width: 6, height: 6)
                                Text("\(wifi.rssi) dBm")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: DeckTheme.Spacing.sm) {
                            Text(String(format: "sysinfo.wifi_channel_format".localized, wifi.band, "\(wifi.channel)"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(wifi.standard)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            if wifi.transmitRateMbps > 0 {
                                Text("\(Int(wifi.transmitRateMbps)) Mbps")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(DeckTheme.Colors.infoBlue)
                            }
                        }
                    }
                    .padding(.bottom, 4)

                    Divider()
                        .padding(.vertical, 2)
                }

                // 局域网 IPv4
                copyableRow(title: "IPv4", value: report.network.primaryIPv4, key: "ipv4")

                // 全球单播 IPv6
                if let g6 = report.network.ipv6Global {
                    copyableRow(title: "sysinfo.ipv6_global".localized, value: g6, key: "ipv6_global")
                }

                // 本地链路 IPv6
                if let l6 = report.network.ipv6LinkLocal {
                    copyableRow(title: "sysinfo.ipv6_link_local".localized, value: l6, key: "ipv6_linklocal")
                }

                // MAC 地址
                copyableRow(title: "MAC", value: report.network.macAddress, key: "mac")

                // 网关与 DNS
                if let gateway = report.network.defaultGateway {
                    HStack {
                        Text("\("sysinfo.gateway_label".localized):")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(gateway)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                if !report.network.dnsServers.isEmpty {
                    HStack {
                        Text("\("sysinfo.dns_label".localized):")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(report.network.dnsServers.joined(separator: ", "))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Divider()
                    .padding(.vertical, 2)

                // 公网 IP 探测区 (保护隐私，按需点击)
                if let pubIP = vm.report?.network.publicIPv4 {
                    HStack {
                        copyableRow(title: "sysinfo.public_ip_label".localized, value: pubIP, key: "public_ip")
                        Spacer()
                        if vm.isProbingPublicIP {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button(action: {
                                Task {
                                    await vm.fetchPublicIP()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("sysinfo.public_ip_reprobe_help".localized)
                        }
                    }
                } else {
                    HStack {
                        Text("\("sysinfo.public_ip_label".localized):")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        if vm.isProbingPublicIP {
                            ProgressView()
                                .controlSize(.small)
                            Text("sysinfo.public_ip_probing".localized)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: {
                                Task {
                                    await vm.fetchPublicIP()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 10))
                                    Text("sysinfo.public_ip_click_to_probe".localized)
                                        .font(.system(size: 11))
                                }
                            }
                            .buttonStyle(DeckSecondaryButtonStyle())
                            .help("sysinfo.public_ip_on_demand_help".localized)

                            if let error = vm.publicIPProbeError {
                                Text(error)
                                    .font(.system(size: 10))
                                    .foregroundColor(DeckTheme.Colors.warning)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func copyableRow(title: String, value: String, key: String) -> some View {
        HStack {
            Text("\(title):")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 65, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Button(action: {
                vm.copySingleItem(title: title, value: value)
                copiedItemKey = key
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedItemKey == key {
                        copiedItemKey = nil
                    }
                }
            }) {
                Image(systemName: copiedItemKey == key ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(copiedItemKey == key ? DeckTheme.Colors.success : .secondary)
            }
            .buttonStyle(.plain)
            .help(String(format: "sysinfo.copy_item_help".localized, title))
        }
    }

    private func rssiColor(_ rssi: Int) -> Color {
        if rssi >= -60 {
            return DeckTheme.Colors.success
        } else if rssi >= -75 {
            return DeckTheme.Colors.warning
        } else {
            return DeckTheme.Colors.danger
        }
    }
}
