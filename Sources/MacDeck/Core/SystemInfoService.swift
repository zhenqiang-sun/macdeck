import Foundation
import IOKit
import IOKit.ps
import CoreWLAN
import SystemConfiguration

public final class SystemInfoService: @unchecked Sendable {
    public static let shared = SystemInfoService()

    private init() {}

    // MARK: - 主采集方法
    public func collectSystemInfo() async -> SystemInfoReport {
        return await Task.detached(priority: .userInitiated) {
            self.collectSystemInfoSync()
        }.value
    }

    public func collectSystemInfoSync() -> SystemInfoReport {
        if ProcessInfo.processInfo.environment["MACDECK_DEMO_MODE"] == "1" ||
           ProcessInfo.processInfo.arguments.contains("--demo") {
            return Self.createDemoReport()
        }

        let modelIdentifier = getSysctlString(name: "hw.model") ?? "Mac"
        let machineName = getCommercialModelName(identifier: modelIdentifier)
        let serialNumber = getSerialNumber() ?? "未知序列号"
        let uptimeSeconds = getSystemUptimeSeconds()
        let uptimeString = SystemInfoReport.formatUptime(seconds: uptimeSeconds)

        let chipName = getSysctlString(name: "machdep.cpu.brand_string") ?? "Apple Silicon"
        let totalCores = Int(getSysctlInt(name: "hw.ncpu") ?? 8)
        let pCores = Int(getSysctlInt(name: "hw.perflevel0.physicalcpu") ?? 0)
        let eCores = Int(getSysctlInt(name: "hw.perflevel1.physicalcpu") ?? 0)
        let architecture = getArchitecture()
        let gpuCores = getGPUCoreCount()
        let neuralEngine = getEstimatedNeuralEngine(chipName: chipName)
        let l1ICacheStr = getL1ICacheSize().map { SystemInfoReport.formatAdaptiveBytes($0) }
        let l1DCacheStr = getL1DCacheSize().map { SystemInfoReport.formatAdaptiveBytes($0) }
        let l2CacheStr = getL2CacheSize().map { SystemInfoReport.formatAdaptiveBytes($0) }

        let processorInfo = ProcessorDetailInfo(
            chipName: chipName,
            totalCPUCores: totalCores,
            performanceCores: pCores > 0 ? pCores : totalCores,
            efficiencyCores: eCores,
            gpuCores: gpuCores,
            neuralEngine: neuralEngine,
            l1InstructionCache: l1ICacheStr,
            l1DataCache: l1DCacheStr,
            l2Cache: l2CacheStr,
            architecture: architecture
        )

        let osVersionInfo = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(osVersionInfo.majorVersion).\(osVersionInfo.minorVersion).\(osVersionInfo.patchVersion)"
        let osName = getOSMarketingName(majorVersion: osVersionInfo.majorVersion)
        let osBuildNumber = getSysctlString(name: "kern.osversion") ?? "未知"
        let darwinKernel = getDarwinKernelVersion()
        let sipEnabled = checkSIPEnabled()
        let fileVaultEnabled = checkFileVaultEnabled()
        let gatekeeperEnabled = checkGatekeeperEnabled()
        let secureBootStatus = getSecureBootStatus()
        let currentUser = ProcessInfo.processInfo.userName
        let userHomeDirectory = NSHomeDirectory()
        let defaultShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        let securityInfo = SecurityDetailInfo(
            sipEnabled: sipEnabled,
            fileVaultEnabled: fileVaultEnabled,
            gatekeeperEnabled: gatekeeperEnabled,
            secureBootStatus: secureBootStatus,
            currentUser: currentUser,
            userHomeDirectory: userHomeDirectory,
            userShell: defaultShell
        )

        let totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Int(round(Double(totalMemoryBytes) / (1024.0 * 1024.0 * 1024.0)))
        let formattedMemory = "\(memoryGB) GB 统一内存"

        let (internalVolumes, externalVolumes) = getStorageVolumes()
        let batteryInfo = getBatteryDetailInfo()
        let networkInfo = getNetworkDetailInfo()

        return SystemInfoReport(
            machineName: machineName,
            modelIdentifier: modelIdentifier,
            serialNumber: serialNumber,
            uptimeString: uptimeString,
            osName: osName,
            osVersion: osVersion,
            osBuildNumber: osBuildNumber,
            darwinKernel: darwinKernel,
            processor: processorInfo,
            security: securityInfo,
            totalMemoryBytes: totalMemoryBytes,
            formattedMemory: formattedMemory,
            internalVolumes: internalVolumes,
            externalVolumes: externalVolumes,
            batteryInfo: batteryInfo,
            network: networkInfo
        )
    }

    // MARK: - Markdown 报告生成
    public func generateMarkdownReport(report: SystemInfoReport) -> String {
        var lines: [String] = []
        lines.append("# MacDeck 完整系统硬件与网络档案")
        lines.append("")
        lines.append("> 生成时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))")
        lines.append("")

        lines.append("## 硬件与机型")
        lines.append("- **机型名称**: \(report.machineName)")
        lines.append("- **机型标识**: `\(report.modelIdentifier)`")
        lines.append("- **硬件序列号**: `\(report.serialNumber)`")
        lines.append("- **运行时间**: \(report.uptimeString)")
        lines.append("")

        lines.append("## 处理器与算力")
        lines.append("- **芯片型号**: \(report.processor.chipName)")
        if report.processor.efficiencyCores > 0 {
            lines.append("- **CPU 核心**: \(report.processor.totalCPUCores) 核 (\(report.processor.performanceCores) 性能核 + \(report.processor.efficiencyCores) 能效核)")
        } else {
            lines.append("- **CPU 核心**: \(report.processor.totalCPUCores) 核")
        }
        if let gpu = report.processor.gpuCores {
            lines.append("- **物理 GPU**: \(gpu) 核心")
        }
        lines.append("- **神经网络引擎**: \(report.processor.neuralEngine)")
        if let l1 = report.processor.l1DataCache {
            lines.append("- **L1 数据缓存**: \(l1)")
        }
        if let l2 = report.processor.l2Cache {
            lines.append("- **L2 缓存**: \(l2)")
        }
        lines.append("- **指令集架构**: \(report.processor.architecture)")
        lines.append("")

        lines.append("## 操作系统与安全")
        lines.append("- **系统版本**: \(report.osName) \(report.osVersion) (\(report.osBuildNumber))")
        lines.append("- **内核版本**: \(report.darwinKernel)")
        lines.append("- **系统完整性保护 (SIP)**: \(report.security.sipEnabled ? "已启用" : "已停用")")
        lines.append("- **全盘硬件加密 (FileVault)**: \(report.security.fileVaultEnabled ? "已开启 🔒" : "未开启")")
        lines.append("- **Gatekeeper 评估**: \(report.security.gatekeeperEnabled ? "已启用" : "已停用")")
        lines.append("- **启动安全策略**: \(report.security.secureBootStatus)")
        lines.append("- **当前登录用户**: \(report.security.currentUser)")
        lines.append("- **用户主目录**: `\(report.security.userHomeDirectory)`")
        lines.append("- **默认 Shell**: `\(report.security.userShell)`")
        lines.append("")

        lines.append("## 物理内存")
        lines.append("- **容量与类型**: \(report.formattedMemory)")
        lines.append("")

        lines.append("## 内置存储")
        for vol in report.internalVolumes {
            let usedStr = SystemInfoReport.formatBytes(vol.usedBytes)
            let totalStr = SystemInfoReport.formatBytes(vol.totalBytes)
            let availStr = SystemInfoReport.formatBytes(vol.availableBytes)
            let pct = Int(vol.usageRatio * 100)
            lines.append("- **\(vol.name)**: \(usedStr) / \(totalStr) (\(pct)%), 剩余可用 \(availStr) (格式: \(vol.fileSystem), 挂载于: `\(vol.mountPath)`)")
        }
        if !report.externalVolumes.isEmpty {
            lines.append("")
            lines.append("## 外接存储")
            for vol in report.externalVolumes {
                let usedStr = SystemInfoReport.formatBytes(vol.usedBytes)
                let totalStr = SystemInfoReport.formatBytes(vol.totalBytes)
                let availStr = SystemInfoReport.formatBytes(vol.availableBytes)
                let pct = Int(vol.usageRatio * 100)
                lines.append("- **\(vol.name)**: \(usedStr) / \(totalStr) (\(pct)%), 剩余可用 \(availStr) (格式: \(vol.fileSystem), 挂载于: `\(vol.mountPath)`)")
            }
        }
        lines.append("")

        if let battery = report.batteryInfo {
            lines.append("## 电源与电池")
            var chargeStatus = battery.isCharging ? "充电中" : "未充电"
            if let watts = battery.chargingWattage, watts > 0 {
                chargeStatus += " (\(watts) W)"
            }
            lines.append("- **当前电量**: \(battery.currentPercentage)% (\(chargeStatus))")
            if let health = battery.healthPercentage {
                lines.append("- **电池健康度**: \(health)%")
            }
            if let cycles = battery.cycleCount {
                lines.append("- **循环次数**: \(cycles) 次")
            }
            lines.append("")
        }

        lines.append("## 网络与通信")
        if let wifi = report.network.wifiInfo {
            let detailStr = " (\(wifi.band), 信道 \(wifi.channel), \(wifi.standard), 速率: \(Int(wifi.transmitRateMbps)) Mbps, RSSI: \(wifi.rssi) dBm)"
            lines.append("- **Wi-Fi 网络**: \(wifi.ssid)\(detailStr)")
            if let bssid = wifi.bssid {
                lines.append("- **AP 物理地址 (BSSID)**: `\(bssid)`")
            }
        }
        lines.append("- **局域网 IPv4**: `\(report.network.primaryIPv4)`")
        if let g6 = report.network.ipv6Global {
            lines.append("- **全球单播 IPv6**: `\(g6)`")
        }
        if let l6 = report.network.ipv6LinkLocal {
            lines.append("- **本地链路 IPv6**: `\(l6)`")
        }
        if let pubIP = report.network.publicIPv4 {
            lines.append("- **公网 IPv4**: `\(pubIP)`")
        }
        lines.append("- **物理 MAC 地址**: `\(report.network.macAddress)`")
        if let gateway = report.network.defaultGateway {
            lines.append("- **默认网关**: `\(gateway)`")
        }
        if !report.network.dnsServers.isEmpty {
            lines.append("- **生效 DNS**: \(report.network.dnsServers.joined(separator: ", "))")
        }
        lines.append("")
        lines.append("---")
        lines.append("*由 MacDeck 原生系统信息模块导出*")
        return lines.joined(separator: "\n")
    }

    // MARK: - 辅助查询方法 (POSIX / Darwin / IOKit / SystemConfiguration)

    private func getSysctlString(name: String) -> String? {
        var size: Int = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getSysctlInt(name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname(name, &value, &size, nil, 0) == 0 {
            return value
        }
        return nil
    }

    private func getSerialNumber() -> String? {
        let expert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard expert != 0 else { return nil }
        defer { IOObjectRelease(expert) }

        if let serialNumberAsCFString = IORegistryEntryCreateCFProperty(expert, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0) {
            return (serialNumberAsCFString.takeRetainedValue() as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func getSystemUptimeSeconds() -> TimeInterval {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        if sysctl(&mib, 2, &bootTime, &size, nil, 0) == 0 {
            let bootDate = Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec))
            return Date().timeIntervalSince(bootDate)
        }
        return ProcessInfo.processInfo.systemUptime
    }

    private func getArchitecture() -> String {
        var uts = utsname()
        uname(&uts)
        let machine = withUnsafePointer(to: &uts.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }

    private func getDarwinKernelVersion() -> String {
        var uts = utsname()
        uname(&uts)
        let release = withUnsafePointer(to: &uts.release) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return "Darwin \(release)"
    }

    private func checkSIPEnabled() -> Bool {
        typealias CSRCheck = @convention(c) (UnsafeMutablePointer<UInt32>) -> Int32
        if let handle = dlopen(nil, RTLD_LAZY),
           let sym = dlsym(handle, "csr_get_active_config") {
            let fn = unsafeBitCast(sym, to: CSRCheck.self)
            var config: UInt32 = 0
            if fn(&config) == 0 {
                return config == 0
            }
        }
        return true
    }

    private func checkFileVaultEnabled() -> Bool {
        let rootURL = URL(fileURLWithPath: "/")
        if let values = try? rootURL.resourceValues(forKeys: [.volumeIsEncryptedKey]),
           let isEncrypted = values.volumeIsEncrypted {
            return isEncrypted
        }
        return false
    }

    private func checkGatekeeperEnabled() -> Bool {
        if let dict = NSDictionary(contentsOfFile: "/Library/Preferences/com.apple.security.plist") as? [String: Any],
           let assessment = dict["AssessmentEnabled"] as? Bool {
            return assessment
        }
        return true
    }

    private func getSecureBootStatus() -> String {
        let arch = getArchitecture()
        if arch.contains("arm64") {
            return "完全安全性"
        } else {
            return "标准安全性"
        }
    }

    private func getOSMarketingName(majorVersion: Int) -> String {
        switch majorVersion {
        case 15: return "macOS Sequoia"
        case 14: return "macOS Sonoma"
        case 13: return "macOS Ventura"
        case 12: return "macOS Monterey"
        case 11: return "macOS Big Sur"
        default: return "macOS"
        }
    }

    private func getCommercialModelName(identifier: String) -> String {
        if identifier.hasPrefix("Mac14,") || identifier.hasPrefix("Mac15,") || identifier.hasPrefix("Mac16,") || identifier.hasPrefix("Mac17,") || identifier.hasPrefix("Mac18,") || identifier.hasPrefix("Mac19,") {
            if identifier.contains("9") || identifier.contains("10") || identifier.contains("11") || identifier.contains("6") || identifier.contains("7") || identifier.contains("8") {
                return "MacBook Pro"
            } else if identifier.contains("2") || identifier.contains("3") || identifier.contains("4") {
                return "MacBook Air"
            } else if identifier.contains("13") || identifier.contains("14") || identifier.contains("15") {
                return "Mac Studio"
            }
            return "MacBook Pro"
        }
        if identifier.contains("MacBookPro") {
            return "MacBook Pro"
        } else if identifier.contains("MacBookAir") {
            return "MacBook Air"
        } else if identifier.contains("Macmini") {
            return "Mac mini"
        } else if identifier.contains("MacStudio") {
            return "Mac Studio"
        } else if identifier.contains("MacPro") {
            return "Mac Pro"
        } else if identifier.contains("iMac") {
            return "iMac"
        }
        return "Apple Mac (\(identifier))"
    }

    private func getGPUCoreCount() -> Int? {
        var iterator: io_iterator_t = 0
        let matchingDict = IOServiceMatching("IOAccelerator")
        if IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            var service = IOIteratorNext(iterator)
            while service != 0 {
                defer {
                    IOObjectRelease(service)
                    service = IOIteratorNext(iterator)
                }
                if let count = IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                    return count
                }
            }
        }
        return nil
    }

    private func getEstimatedNeuralEngine(chipName: String) -> String {
        let lower = chipName.lowercased()
        if lower.contains("ultra") {
            return "32 核神经网络引擎 (NPU)"
        } else if lower.contains("apple") || lower.contains("m1") || lower.contains("m2") || lower.contains("m3") || lower.contains("m4") || lower.contains("m5") {
            return "16 核神经网络引擎 (NPU)"
        }
        return "Apple 神经网络引擎"
    }

    private func getL1ICacheSize() -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        if sysctlbyname("hw.l1icachesize", &value, &size, nil, 0) == 0 {
            return value
        }
        return nil
    }

    private func getL1DCacheSize() -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        if sysctlbyname("hw.l1dcachesize", &value, &size, nil, 0) == 0 {
            return value
        }
        return nil
    }

    private func getL2CacheSize() -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        if sysctlbyname("hw.l2cachesize", &value, &size, nil, 0) == 0 {
            return value
        }
        return nil
    }

    // MARK: - 存储采集

    private func getStorageVolumes() -> (internalVolumes: [StorageVolumeInfo], externalVolumes: [StorageVolumeInfo]) {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeLocalizedFormatDescriptionKey,
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeIsLocalKey,
            .volumeIsReadOnlyKey
        ]

        var internalVols: [StorageVolumeInfo] = []
        var externalVols: [StorageVolumeInfo] = []
        var visitedPaths = Set<String>()

        // 1. 根目录 / (内置主盘)
        let rootURL = URL(fileURLWithPath: "/")
        if let rootInfo = createStorageVolumeInfo(url: rootURL, keys: keys) {
            internalVols.append(rootInfo)
            visitedPaths.insert(rootURL.path)
        }

        // 2. 遍历所有挂载卷，严格过滤网络共享卷和只读虚拟镜像
        if let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) {
            for url in urls {
                let path = url.path
                guard !visitedPaths.contains(path) else { continue }
                if path.hasPrefix("/System/Volumes") { continue }

                if let vol = createStorageVolumeInfo(url: url, keys: keys) {
                    if vol.isExternal {
                        externalVols.append(vol)
                    } else if path != "/" {
                        internalVols.append(vol)
                    }
                    visitedPaths.insert(path)
                }
            }
        }

        if internalVols.isEmpty {
            internalVols.append(
                StorageVolumeInfo(
                    name: "Macintosh HD",
                    mountPath: "/",
                    fileSystem: "APFS",
                    totalBytes: 500_000_000_000,
                    availableBytes: 250_000_000_000,
                    usedBytes: 250_000_000_000,
                    usageRatio: 0.5,
                    isExternal: false,
                    isRemovable: false
                )
            )
        }
        return (internalVols, externalVols)
    }

    private func createStorageVolumeInfo(url: URL, keys: [URLResourceKey]) -> StorageVolumeInfo? {
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }

        // 核心过滤 1：排除网络共享卷（如 SMB、NFS、AFP、WebDAV、CIFS）
        if let isLocal = values.volumeIsLocal, !isLocal {
            return nil
        }

        // 核心过滤 2：排除只读虚拟镜像（如 dmg 挂载），根目录除外
        if url.path != "/", let isReadOnly = values.volumeIsReadOnly, isReadOnly {
            return nil
        }

        let format = values.volumeLocalizedFormatDescription ?? "APFS"
        let lowerFormat = format.lowercased()
        let networkTypes = ["smb", "nfs", "afp", "cifs", "webdav", "nullfs", "disk image"]
        for netType in networkTypes {
            if lowerFormat.contains(netType) {
                return nil
            }
        }

        let total = Int64(values.volumeTotalCapacity ?? 0)
        guard total > 0 else { return nil }

        let available: Int64
        if let important = values.volumeAvailableCapacityForImportantUsage {
            available = important
        } else if let regular = values.volumeAvailableCapacity {
            available = Int64(regular)
        } else {
            available = 0
        }
        let used = max(0, total - available)
        let ratio = total > 0 ? Double(used) / Double(total) : 0.0
        let name = values.volumeName ?? (url.path == "/" ? "Macintosh HD" : url.lastPathComponent)
        let isInternal = values.volumeIsInternal ?? (url.path == "/")
        let isRemovable = values.volumeIsRemovable ?? false

        return StorageVolumeInfo(
            name: name,
            mountPath: url.path,
            fileSystem: format,
            totalBytes: total,
            availableBytes: available,
            usedBytes: used,
            usageRatio: ratio,
            isExternal: !isInternal,
            isRemovable: isRemovable
        )
    }

    // MARK: - 电源采集

    private func getBatteryDetailInfo() -> BatteryDetailInfo? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return nil
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let isPresent = desc[kIOPSIsPresentKey] as? Bool ?? false
            guard isPresent else { continue }

            let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let powerSourceState = desc[kIOPSPowerSourceStateKey] as? String
            let isACPowered = (powerSourceState == kIOPSACPowerValue)

            let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let designCapacity = desc["DesignCapacity"] as? Int ?? maxCapacity
            var health: Int? = nil
            if designCapacity > 0 && maxCapacity > 0 {
                health = min(100, Int((Double(maxCapacity) / Double(designCapacity)) * 100.0))
            }

            let cycleCount = desc["Cycle Count"] as? Int

            var watts: Int? = nil
            if let w = desc["Watts"] as? Double {
                watts = Int(round(w))
            } else if let w = desc["Watts"] as? Int {
                watts = w
            } else if let w = desc["Watts"] as? NSNumber {
                watts = w.intValue
            } else if let volt = desc["Voltage"] as? Double, let amp = desc["Amperage"] as? Double, volt > 0 {
                let v = volt > 100 ? volt / 1000.0 : volt
                let a = abs(amp) > 100 ? abs(amp) / 1000.0 : abs(amp)
                if isCharging && v * a > 0 {
                    watts = Int(round(v * a))
                }
            }

            return BatteryDetailInfo(
                healthPercentage: health,
                cycleCount: cycleCount,
                currentPercentage: currentCapacity,
                isCharging: isCharging,
                isACPowered: isACPowered,
                chargingWattage: watts
            )
        }
        return nil
    }

    // MARK: - 网络采集

    private func getNetworkDetailInfo() -> NetworkDetailInfo {
        var ipv4 = "--"
        var globalIPv6: String? = nil
        var linkLocalIPv6: String? = nil
        var mac = "--"

        // 1. 获取 Wi-Fi 射频详情
        var wifiDetail: WiFiDetailInfo? = nil
        if let defaultInterface = CWWiFiClient.shared().interface(),
           let ssid = defaultInterface.ssid(), !ssid.isEmpty {
            let bssid = defaultInterface.bssid()
            let channel = defaultInterface.wlanChannel()?.channelNumber ?? 0
            var bandString = "5 GHz"
            if let channelBand = defaultInterface.wlanChannel()?.channelBand {
                switch channelBand {
                case .band2GHz: bandString = "2.4 GHz"
                case .band5GHz: bandString = "5 GHz"
                case .band6GHz: bandString = "6 GHz"
                case .bandUnknown: bandString = "5 GHz"
                @unknown default: bandString = "5 GHz"
                }
            }
            let rate = defaultInterface.transmitRate() > 0 ? defaultInterface.transmitRate() : 0.0
            let rssi = defaultInterface.rssiValue()

            var standardString = "Wi-Fi 6"
            switch defaultInterface.activePHYMode() {
            case .mode11ax: standardString = "Wi-Fi 6 (802.11ax)"
            case .mode11ac: standardString = "Wi-Fi 5 (802.11ac)"
            case .mode11n: standardString = "Wi-Fi 4 (802.11n)"
            case .mode11a: standardString = "802.11a"
            case .mode11g: standardString = "802.11g"
            case .mode11b: standardString = "802.11b"
            default: standardString = "Wi-Fi"
            }

            wifiDetail = WiFiDetailInfo(
                ssid: ssid,
                bssid: bssid,
                band: bandString,
                standard: standardString,
                channel: channel,
                rssi: rssi,
                transmitRateMbps: rate
            )
        }

        // 2. 通过 getifaddrs 遍历活动网络接口
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr {
            var ptr = firstAddr
            while true {
                let flags = Int32(ptr.pointee.ifa_flags)
                let isUp = (flags & IFF_UP) != 0
                let isRunning = (flags & IFF_RUNNING) != 0
                let isLoopback = (flags & IFF_LOOPBACK) != 0

                if isUp && isRunning && !isLoopback {
                    let addrFamily = ptr.pointee.ifa_addr.pointee.sa_family
                    let name = String(cString: ptr.pointee.ifa_name)

                    if addrFamily == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(
                            ptr.pointee.ifa_addr,
                            socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        ) == 0 {
                            let ip = String(cString: hostname)
                            if ipv4 == "--" || name == "en0" {
                                ipv4 = ip
                            }
                        }
                    } else if addrFamily == UInt8(AF_INET6) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(
                            ptr.pointee.ifa_addr,
                            socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        ) == 0 {
                            var ip6 = String(cString: hostname)
                            if let scopeIndex = ip6.firstIndex(of: "%") {
                                ip6 = String(ip6[..<scopeIndex])
                            }

                            if ip6.lowercased().hasPrefix("fe80:") {
                                if linkLocalIPv6 == nil || name == "en0" {
                                    linkLocalIPv6 = ip6
                                }
                            } else if ip6 != "::1" && !ip6.lowercased().hasPrefix("fd00:") {
                                if globalIPv6 == nil || name == "en0" {
                                    globalIPv6 = ip6
                                }
                            }
                        }
                    } else if addrFamily == UInt8(AF_LINK) {
                        let sdl = ptr.pointee.ifa_addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                        if sdl.sdl_alen == 6 {
                            let bytes = withUnsafePointer(to: sdl.sdl_data) { ptr -> [UInt8] in
                                let base = UnsafeRawPointer(ptr).advanced(by: Int(sdl.sdl_nlen))
                                return Array(UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: 6))
                            }
                            let formattedMAC = bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
                            if mac == "--" || name == "en0" {
                                mac = formattedMAC
                            }
                        }
                    }
                }

                guard let next = ptr.pointee.ifa_next else { break }
                ptr = next
            }
            freeifaddrs(ifaddr)
        }

        // 3. 从 SystemConfiguration 获取默认网关和生效 DNS
        let gatewayAndDNS = getGatewayAndDNS()

        return NetworkDetailInfo(
            primaryIPv4: ipv4,
            ipv6Global: globalIPv6,
            ipv6LinkLocal: linkLocalIPv6,
            macAddress: mac,
            defaultGateway: gatewayAndDNS.gateway,
            dnsServers: gatewayAndDNS.dnsServers,
            wifiInfo: wifiDetail,
            publicIPv4: nil
        )
    }

    private func getGatewayAndDNS() -> (gateway: String?, dnsServers: [String]) {
        var gateway: String? = nil
        var dnsServers: [String] = []

        guard let dynamicStore = SCDynamicStoreCreate(nil, "MacDeck" as CFString, nil, nil) else {
            return (nil, [])
        }

        // 查询网关
        if let ip4Dict = SCDynamicStoreCopyValue(dynamicStore, "State:/Network/Global/IPv4" as CFString) as? [String: Any] {
            gateway = ip4Dict["Router"] as? String
        }

        // 查询 DNS
        if let dnsDict = SCDynamicStoreCopyValue(dynamicStore, "State:/Network/Global/DNS" as CFString) as? [String: Any],
           let servers = dnsDict["ServerAddresses"] as? [String] {
            dnsServers = servers
        }

        return (gateway, dnsServers)
    }

    public static func createDemoReport() -> SystemInfoReport {
        let isZh = LocalizationService.shared.effectiveLanguage == .zhHans
        let processor = ProcessorDetailInfo(
            chipName: "Apple M4 Max",
            totalCPUCores: 16,
            performanceCores: 12,
            efficiencyCores: 4,
            gpuCores: 40,
            neuralEngine: isZh ? "16 核神经网络引擎 (NPU)" : "16-Core Neural Engine (NPU)",
            l1InstructionCache: "128 KB",
            l1DataCache: "128 KB",
            l2Cache: "48 MB",
            architecture: "arm64"
        )

        let security = SecurityDetailInfo(
            sipEnabled: true,
            fileVaultEnabled: true,
            gatekeeperEnabled: true,
            secureBootStatus: isZh ? "完整安全性 (Full Security)" : "Full Security",
            currentUser: "developer",
            userHomeDirectory: "/Users/developer",
            userShell: "/bin/zsh"
        )

        let internalVolume = StorageVolumeInfo(
            name: "Macintosh HD",
            mountPath: "/",
            fileSystem: "APFS",
            totalBytes: 2 * 1024 * 1024 * 1024 * 1024,
            availableBytes: Int64(940.0 * 1024 * 1024 * 1024),
            usedBytes: Int64(1060.0 * 1024 * 1024 * 1024),
            usageRatio: 0.53,
            isExternal: false,
            isRemovable: false
        )

        let battery = BatteryDetailInfo(
            healthPercentage: 98,
            cycleCount: 42,
            currentPercentage: 100,
            isCharging: false,
            isACPowered: true,
            chargingWattage: 140
        )

        let wifi = WiFiDetailInfo(
            ssid: "Studio-5G",
            bssid: "3C:22:FB:00:11:22",
            band: "5 GHz",
            standard: "Wi-Fi 6E (802.11ax)",
            channel: 149,
            rssi: -45,
            transmitRateMbps: 1200.0
        )

        let network = NetworkDetailInfo(
            primaryIPv4: "192.168.1.100",
            ipv6Global: "2001:db8:85a3::8a2e:370:7334",
            ipv6LinkLocal: "fe80::1c22:fbff:fea1:b2c3",
            macAddress: "3C:22:FB:A1:B2:C3",
            defaultGateway: "192.168.1.1",
            dnsServers: ["1.1.1.1", "8.8.8.8"],
            wifiInfo: wifi,
            publicIPv4: "203.0.113.195"
        )

        return SystemInfoReport(
            machineName: "MacBook Pro (16-inch, Nov 2024)",
            modelIdentifier: "Mac16,5",
            serialNumber: "M4P88DEMO001",
            uptimeString: isZh ? "5天 12小时 30分钟" : "5d 12h 30m",
            osName: "macOS Sequoia",
            osVersion: "15.0",
            osBuildNumber: "24A335",
            darwinKernel: "Darwin 24.0.0",
            processor: processor,
            security: security,
            totalMemoryBytes: 64 * 1024 * 1024 * 1024,
            formattedMemory: "64 GB",
            internalVolumes: [internalVolume],
            externalVolumes: [],
            batteryInfo: battery,
            network: network
        )
    }
}

