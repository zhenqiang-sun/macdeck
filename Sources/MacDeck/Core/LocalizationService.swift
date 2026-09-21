import Foundation
import SwiftUI
import Combine

/// 支持的应用界面语言
public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case en = "en"
    case zhHans = "zh-Hans"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return "Follow System / 跟随系统"
        case .en:
            return "English"
        case .zhHans:
            return "简体中文"
        }
    }
}

/// 核心本地化与国际化管理服务 (Thread-safe, Observable)
public final class LocalizationService: ObservableObject {
    public static let shared = LocalizationService()

    private let languageStorageKey = "com.agy.MacDeck.appLanguage"

    @Published public private(set) var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: languageStorageKey)
            updateEffectiveLanguage()
        }
    }

    /// 当前实际生效的语言 (en 或 zh-Hans)
    @Published public private(set) var effectiveLanguage: AppLanguage = .en

    private init() {
        let savedRaw = UserDefaults.standard.string(forKey: languageStorageKey) ?? AppLanguage.system.rawValue
        let initialSelection = AppLanguage(rawValue: savedRaw) ?? .system
        self.selectedLanguage = initialSelection
        self.effectiveLanguage = Self.resolveEffectiveLanguage(from: initialSelection)
    }

    /// 设置应用语言
    public func setLanguage(_ language: AppLanguage) {
        guard language != selectedLanguage else { return }
        self.selectedLanguage = language
    }

    private func updateEffectiveLanguage() {
        let resolved = Self.resolveEffectiveLanguage(from: selectedLanguage)
        if effectiveLanguage != resolved {
            effectiveLanguage = resolved
        }
    }

    /// 判定实际生效语言：
    /// 若设为 system，优先根据系统语言首选项判定；若系统为中文则返回 zhHans，其余全部默认返回 en。
    public static func resolveEffectiveLanguage(from selection: AppLanguage) -> AppLanguage {
        switch selection {
        case .en:
            return .en
        case .zhHans:
            return .zhHans
        case .system:
            let preferred = Locale.preferredLanguages.first ?? ""
            if preferred.hasPrefix("zh") {
                return .zhHans
            }
            return .en
        }
    }

    private var loadedLanguagePacks: [String: [String: String]] = [:]

    private func loadPackIfNeeded(languageCode: String) -> [String: String] {
        if let cached = loadedLanguagePacks[languageCode] {
            return cached
        }

        // 尝试从多个候选路径寻找 Locales/<code_mapping>.json
        var candidateURLs: [URL] = []

        if let resURL = Bundle.main.resourceURL {
            candidateURLs.append(resURL.appendingPathComponent("Locales/\(languageCode).json"))
            candidateURLs.append(resURL.appendingPathComponent("\(languageCode).json"))
        }
        if let path = Bundle.main.path(forResource: languageCode, ofType: "json", inDirectory: "Locales") {
            candidateURLs.append(URL(fileURLWithPath: path))
        }

        // 源码开发相对路径回退
        let sourceRelative = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // MacDeck
            .appendingPathComponent("Resources/Locales/\(languageCode).json")
        candidateURLs.append(sourceRelative)

        let rootSourceRelative = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // MacDeck
            .deletingLastPathComponent() // Sources
            .appendingPathComponent("Resources/Locales/\(languageCode).json")
        candidateURLs.append(rootSourceRelative)

        for url in candidateURLs {
            if FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let flattened = Self.flatten(dictionary: json)
                if !flattened.isEmpty {
                    loadedLanguagePacks[languageCode] = flattened
                    return flattened
                }
            }
        }

        return [:]
    }

    private static func flatten(dictionary: [String: Any], prefix: String = "") -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            let combinedKey = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let nested = value as? [String: Any] {
                let subResult = flatten(dictionary: nested, prefix: combinedKey)
                for (k, v) in subResult {
                    result[k] = v
                }
            } else if let str = value as? String {
                result[combinedKey] = str
            }
        }
        return result
    }

    /// 本地化查询（优先外部语言包，若无则回退到内置字典）
    public func localizedString(forKey key: String) -> String {
        let code = (effectiveLanguage == .zhHans ? "zh-Hans" : "en")
        let pack = loadPackIfNeeded(languageCode: code)
        if let val = pack[key] {
            return val
        }

        // 回退机制
        if effectiveLanguage == .zhHans {
            return Self.zhDictionary[key] ?? Self.enDictionary[key] ?? key
        } else {
            return Self.enDictionary[key] ?? Self.zhDictionary[key] ?? key
        }
    }

    /// 支持带格式化参数的本地化
    public func localizedString(forKey key: String, arguments: [CVarArg]) -> String {
        let format = localizedString(forKey: key)
        return String(format: format, locale: (effectiveLanguage == .zhHans ? Locale(identifier: "zh-Hans") : Locale(identifier: "en")), arguments: arguments)
    }

    // MARK: - 双语词典

    private static let enDictionary: [String: String] = [
        // Navigation & Sidebar
        "nav.displays": "Displays & Presets",
        "nav.window_layout": "Window Restoring",
        "nav.system_info": "System Dossier",
        "nav.environment": "Environment Doctor",
        "nav.software_update": "Software Updates",
        "nav.settings": "Settings",
        "nav.footer_author": "MacDeck · macOS Native Assistant",

        // Common Actions & Status
        "common.refresh": "Refresh",
        "common.cancel": "Cancel",
        "common.confirm": "Confirm",
        "common.save": "Save",
        "common.edit": "Edit",
        "common.delete": "Delete",
        "common.done": "Done",
        "common.copy": "Copy",
        "common.copied": "Copied",
        "common.search": "Search",
        "common.loading": "Loading...",
        "common.success": "Success",
        "common.warning": "Warning",
        "common.error": "Error",
        "common.close": "Close",
        "common.enabled": "Enabled",
        "common.disabled": "Disabled",
        "common.yes": "Yes",
        "common.no": "No",
        "common.all": "All",
        "common.retry": "Retry",

        // Displays Overview & Window Restoring
        "displays.active_topology": "Active Topology",
        "displays.topology_fingerprint": "Fingerprint",
        "displays.displays_count": "%d Displays",
        "displays.restore_all": "Restore All Windows",
        "displays.restore_preset": "Restore",
        "displays.record_window": "Capture",
        "displays.add_preset": "New Preset",
        "displays.delete_preset": "Delete Preset",
        "displays.rename_preset": "Rename Preset",
        "displays.preset_name_placeholder": "e.g., Default Layout, Coding Mode",
        "displays.no_windows_recorded": "No windows recorded in this preset.",
        "displays.capture_all_current": "Snapshot Current Windows",
        "displays.restore_in_progress": "Restoring windows to their positions...",
        "displays.restore_completed": "Restoration completed: restored %d windows",
        "displays.window_restored_single": "Restored %@",
        "displays.window_not_found": "%@ window not found, please ensure it is open",
        "displays.fullscreen_tag": "Full Screen",
        "displays.minimized_tag": "Minimized",
        "displays.alias_editing": "Edit Display Alias",
        "displays.alias_placeholder": "e.g., UltraWide, Portrait Left",
        "displays.switch_topology_prompt": "Hardware topology switched to [%@]",
        "displays.topology_not_matched": "Current hardware does not match saved topology",
        "displays.align_hardware": "Align Hardware",

        // System Info (System Dossier)
        "sysinfo.title": "System Hardware & Network Dossier",
        "sysinfo.copy_report": "Copy Full Report",
        "sysinfo.copy_report_success": "Full system report copied to clipboard",
        "sysinfo.soc_uma_card": "Apple Silicon SoC & Unified Memory",
        "sysinfo.chip_model": "Processor",
        "sysinfo.cores_summary": "%d Cores (%d Performance + %d Efficiency)",
        "sysinfo.gpu_cores": "%d GPU Cores",
        "sysinfo.neural_engine": "Neural Engine",
        "sysinfo.l1_instruction_cache": "L1 Inst Cache",
        "sysinfo.l1_data_cache": "L1 Data Cache",
        "sysinfo.l2_cache": "L2 Cache",
        "sysinfo.unified_memory": "Unified Memory",
        "sysinfo.memory_speed": "Memory Type",
        "sysinfo.os_and_hardware": "System & Hardware",
        "sysinfo.device_model": "Hardware Model",
        "sysinfo.macos_version": "macOS Version",
        "sysinfo.kernel_version": "Darwin Kernel",
        "sysinfo.serial_number": "Serial Number",
        "sysinfo.uptime": "System Uptime",
        "sysinfo.power_and_battery": "Battery & Power Health",
        "sysinfo.battery_health": "Health Condition",
        "sysinfo.battery_cycles": "Cycle Count",
        "sysinfo.battery_capacity": "Max Capacity",
        "sysinfo.charging_status": "Power Source",
        "sysinfo.power_adapter": "AC Adapter",
        "sysinfo.storage_volumes": "Internal Storage (APFS)",
        "sysinfo.volume_used": "%@ of %@ used (%d%%)",
        "sysinfo.volume_free": "%@ available",
        "sysinfo.network_and_internet": "Network & Internet",
        "sysinfo.primary_ipv4": "Primary IPv4",
        "sysinfo.public_ip": "Public Exit IP",
        "sysinfo.public_ip_click_to_probe": "Click to Probe",
        "sysinfo.public_ip_probing": "Probing...",
        "sysinfo.public_ip_reprobe": "Re-probe public IP",
        "sysinfo.public_ip_failed": "Probe timed out or unreachable",
        "sysinfo.mac_address": "MAC Address",
        "sysinfo.gateway": "Default Gateway",
        "sysinfo.dns_servers": "DNS Servers",
        "sysinfo.ipv6_global": "IPv6 Global",
        "sysinfo.wifi_ssid": "Wi-Fi SSID",
        "sysinfo.wifi_bssid": "Wi-Fi BSSID",
        "sysinfo.wifi_channel": "Wi-Fi Channel",
        "sysinfo.wifi_rssi": "Wi-Fi RSSI",
        "sysinfo.wifi_tx_rate": "Tx Rate",

        // Environment Doctor
        "doctor.title": "Development Environment Doctor",
        "doctor.scan": "Diagnose All",
        "doctor.clean": "Clean Selected Items",
        "doctor.status_healthy": "Healthy",
        "doctor.status_warning": "Warning",
        "doctor.status_error": "Error",
        "doctor.cleanable_cache": "Cleanable Cache: %@",
        "doctor.cleaning": "Cleaning...",
        "doctor.clean_finished": "Cleaning finished, reclaimed %@",
        "doctor.console_output": "Terminal Diagnostic Output",

        // Software Update
        "update.title": "Multi-Source Software Update",
        "update.check_updates": "Check Updates",
        "update.checking": "Checking...",
        "update.upgrade_selected": "Upgrade Selected (%d)",
        "update.package_name": "Package Name",
        "update.current_version": "Current",
        "update.latest_version": "Latest",
        "update.source": "Source",
        "update.pin_version": "Pin Version",
        "update.ignore_version": "Ignore Version",
        "update.history": "Update History",
        "update.rollback": "Rollback",
        "update.no_updates_available": "All packages are up to date.",

        // Settings View
        "settings.title": "Preferences",
        "settings.general_tab": "General",
        "settings.language_section": "Appearance & Language",
        "settings.language_label": "Interface Language",
        "settings.auto_quit_label": "Auto Quit After Window Restoration",
        "settings.auto_quit_desc": "Automatically terminate MacDeck after restoring windows to preserve memory.",
        "settings.launch_at_login": "Launch at Login",
        "settings.about_section": "About MacDeck",
        "settings.version": "Version",
        "settings.license": "License: GNU GPL v3.0",
        "settings.github_repo": "GitHub Repository",

        // Permissions Banner
        "permission.banner_title": "Accessibility Permission Required",
        "permission.banner_desc": "MacDeck needs Accessibility permission to detect and reposition windows across your displays.",
        "permission.grant_button": "Open System Settings"
    ]

    private static let zhDictionary: [String: String] = [
        // Navigation & Sidebar
        "nav.displays": "多屏拓扑",
        "nav.window_layout": "窗口归位",
        "nav.system_info": "系统档案",
        "nav.environment": "环境维护",
        "nav.software_update": "软件更新",
        "nav.settings": "偏好设置",
        "nav.footer_author": "MacDeck · macOS 原生极客工具箱",

        // Common Actions & Status
        "common.refresh": "刷新",
        "common.cancel": "取消",
        "common.confirm": "确认",
        "common.save": "保存",
        "common.edit": "编辑",
        "common.delete": "删除",
        "common.done": "完成",
        "common.copy": "复制",
        "common.copied": "已复制",
        "common.search": "搜索",
        "common.loading": "加载中...",
        "common.success": "成功",
        "common.warning": "警告",
        "common.error": "错误",
        "common.close": "关闭",
        "common.enabled": "已启用",
        "common.disabled": "已禁用",
        "common.yes": "是",
        "common.no": "否",
        "common.all": "全部",
        "common.retry": "重试",

        // Displays Overview & Window Restoring
        "displays.active_topology": "当前屏幕环境",
        "displays.topology_fingerprint": "拓扑指纹",
        "displays.displays_count": "%d 台显示器",
        "displays.restore_all": "一键全部归位",
        "displays.restore_preset": "方案归位",
        "displays.record_window": "记录位置",
        "displays.add_preset": "新增方案",
        "displays.delete_preset": "删除方案",
        "displays.rename_preset": "重命名方案",
        "displays.preset_name_placeholder": "例如：默认方案、沉浸开发模式",
        "displays.no_windows_recorded": "当前方案下尚未记录任何窗口。",
        "displays.capture_all_current": "快照当前所有窗口",
        "displays.restore_in_progress": "正在执行窗口归位...",
        "displays.restore_completed": "已全部归位：成功复原 %d 个窗口",
        "displays.window_restored_single": "已归位 %@",
        "displays.window_not_found": "未找到 %@ 窗口，请确认是否已打开",
        "displays.fullscreen_tag": "全屏",
        "displays.minimized_tag": "最小化",
        "displays.alias_editing": "修改显示器别名",
        "displays.alias_placeholder": "例如：带鱼主屏、左侧竖屏",
        "displays.switch_topology_prompt": "硬件环境已自动切换至【%@】",
        "displays.topology_not_matched": "当前物理硬件与已保存环境不吻合",
        "displays.align_hardware": "对齐硬件",

        // System Info (System Dossier)
        "sysinfo.title": "系统完整硬件与网络档案",
        "sysinfo.copy_report": "复制完整报告",
        "sysinfo.copy_report_success": "已复制完整系统报告至剪贴板",
        "sysinfo.soc_uma_card": "Apple Silicon SoC 芯片与统一内存架构",
        "sysinfo.chip_model": "处理器型号",
        "sysinfo.cores_summary": "%d 核 CPU (%d 性能核 + %d 能效核)",
        "sysinfo.gpu_cores": "%d 核 图形处理器",
        "sysinfo.neural_engine": "神经网络引擎",
        "sysinfo.l1_instruction_cache": "一级指令缓存",
        "sysinfo.l1_data_cache": "一级数据缓存",
        "sysinfo.l2_cache": "二级高速缓存",
        "sysinfo.unified_memory": "统一内存容量",
        "sysinfo.memory_speed": "内存类型",
        "sysinfo.os_and_hardware": "系统与硬件",
        "sysinfo.device_model": "设备机型",
        "sysinfo.macos_version": "macOS 版本",
        "sysinfo.kernel_version": "Darwin 内核",
        "sysinfo.serial_number": "设备序列号",
        "sysinfo.uptime": "系统运行时间",
        "sysinfo.power_and_battery": "电池与电源健康",
        "sysinfo.battery_health": "电池健康度",
        "sysinfo.battery_cycles": "循环计数",
        "sysinfo.battery_capacity": "最大容量",
        "sysinfo.charging_status": "供电状态",
        "sysinfo.power_adapter": "外接电源",
        "sysinfo.storage_volumes": "内部物理存储 (APFS)",
        "sysinfo.volume_used": "%@ / %@ 已用 (%d%%)",
        "sysinfo.volume_free": "%@ 可用",
        "sysinfo.network_and_internet": "网络与互联网",
        "sysinfo.primary_ipv4": "本机 IPv4",
        "sysinfo.public_ip": "公网出口 IP",
        "sysinfo.public_ip_click_to_probe": "点击探测",
        "sysinfo.public_ip_probing": "探测中...",
        "sysinfo.public_ip_reprobe": "重新探测公网出口 IP",
        "sysinfo.public_ip_failed": "网络探测超时或服务不可达",
        "sysinfo.mac_address": "MAC 地址",
        "sysinfo.gateway": "默认网关",
        "sysinfo.dns_servers": "DNS 服务器",
        "sysinfo.ipv6_global": "IPv6 全局公网",
        "sysinfo.wifi_ssid": "Wi-Fi 名称",
        "sysinfo.wifi_bssid": "AP 物理地址",
        "sysinfo.wifi_channel": "Wi-Fi 信道",
        "sysinfo.wifi_rssi": "信号强度 (RSSI)",
        "sysinfo.wifi_tx_rate": "协商发送速率",

        // Environment Doctor
        "doctor.title": "开发环境体检与维护",
        "doctor.scan": "全面诊断",
        "doctor.clean": "清理选中项",
        "doctor.status_healthy": "健康",
        "doctor.status_warning": "警告",
        "doctor.status_error": "异常",
        "doctor.cleanable_cache": "可清理缓存：%@ ",
        "doctor.cleaning": "正在清理...",
        "doctor.clean_finished": "清理完成，已释放空间 %@",
        "doctor.console_output": "终端诊断输出",

        // Software Update
        "update.title": "多源软件包生态更新",
        "update.check_updates": "检查更新",
        "update.checking": "正在检测...",
        "update.upgrade_selected": "批量升级选中项 (%d)",
        "update.package_name": "软件包名称",
        "update.current_version": "当前版本",
        "update.latest_version": "最新版本",
        "update.source": "包管理器",
        "update.pin_version": "锁定版本",
        "update.ignore_version": "忽略此版",
        "update.history": "更新历史",
        "update.rollback": "一键回滚",
        "update.no_updates_available": "当前所有软件包已处于最新状态。",

        // Settings View
        "settings.title": "偏好设置",
        "settings.general_tab": "通用设置",
        "settings.language_section": "外观与语言",
        "settings.language_label": "界面语言",
        "settings.auto_quit_label": "窗口归位后自动退出 MacDeck",
        "settings.auto_quit_desc": "在完成所有窗口定位后自动终止后台进程，不额外驻留占用内存。",
        "settings.launch_at_login": "开机自动启动",
        "settings.about_section": "关于 MacDeck",
        "settings.version": "当前版本",
        "settings.license": "开源协议：GNU GPL v3.0",
        "settings.github_repo": "GitHub 项目仓库",

        // Permissions Banner
        "permission.banner_title": "需要开启辅助功能权限",
        "permission.banner_desc": "MacDeck 需要通过系统的“辅助功能”权限获取窗口几何信息并在用户指令下调整窗口坐标。",
        "permission.grant_button": "前往系统设置授权"
    ]
}

/// 便捷本地化调用工具
public enum L10n {
    public static func t(_ key: String) -> String {
        return LocalizationService.shared.localizedString(forKey: key)
    }

    public static func t(_ key: String, _ args: CVarArg...) -> String {
        return LocalizationService.shared.localizedString(forKey: key, arguments: args)
    }
}

public extension String {
    var localized: String {
        return LocalizationService.shared.localizedString(forKey: self)
    }

    func localized(_ args: CVarArg...) -> String {
        return LocalizationService.shared.localizedString(forKey: self, arguments: args)
    }
}
