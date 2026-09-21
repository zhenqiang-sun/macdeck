import Foundation

public enum DiskWatermarkLevel: Equatable {
    case healthy
    case warning
    case danger

    public static func evaluate(ratio: Double) -> DiskWatermarkLevel {
        if ratio >= 0.90 {
            return .danger
        } else if ratio >= 0.75 {
            return .warning
        } else {
            return .healthy
        }
    }
}

public struct StorageVolumeInfo: Identifiable, Equatable {
    public var id: String { mountPath }
    public let name: String
    public let mountPath: String
    public let fileSystem: String
    public let totalBytes: Int64
    public let availableBytes: Int64
    public let usedBytes: Int64
    public let usageRatio: Double
    public let isExternal: Bool
    public let isRemovable: Bool

    public init(
        name: String,
        mountPath: String,
        fileSystem: String,
        totalBytes: Int64,
        availableBytes: Int64,
        usedBytes: Int64,
        usageRatio: Double,
        isExternal: Bool,
        isRemovable: Bool
    ) {
        self.name = name
        self.mountPath = mountPath
        self.fileSystem = fileSystem
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.usedBytes = usedBytes
        self.usageRatio = usageRatio
        self.isExternal = isExternal
        self.isRemovable = isRemovable
    }
}

public struct WiFiDetailInfo: Equatable {
    public let ssid: String
    public let bssid: String?
    public let band: String
    public let standard: String
    public let channel: Int
    public let rssi: Int
    public let transmitRateMbps: Double

    public init(
        ssid: String,
        bssid: String? = nil,
        band: String,
        standard: String,
        channel: Int,
        rssi: Int,
        transmitRateMbps: Double
    ) {
        self.ssid = ssid
        self.bssid = bssid
        self.band = band
        self.standard = standard
        self.channel = channel
        self.rssi = rssi
        self.transmitRateMbps = transmitRateMbps
    }
}

public struct NetworkDetailInfo: Equatable {
    public var primaryIPv4: String
    public var ipv6Global: String?
    public var ipv6LinkLocal: String?
    public var macAddress: String
    public var defaultGateway: String?
    public var dnsServers: [String]
    public var wifiInfo: WiFiDetailInfo?
    public var publicIPv4: String?

    public init(
        primaryIPv4: String,
        ipv6Global: String? = nil,
        ipv6LinkLocal: String? = nil,
        macAddress: String,
        defaultGateway: String? = nil,
        dnsServers: [String] = [],
        wifiInfo: WiFiDetailInfo? = nil,
        publicIPv4: String? = nil
    ) {
        self.primaryIPv4 = primaryIPv4
        self.ipv6Global = ipv6Global
        self.ipv6LinkLocal = ipv6LinkLocal
        self.macAddress = macAddress
        self.defaultGateway = defaultGateway
        self.dnsServers = dnsServers
        self.wifiInfo = wifiInfo
        self.publicIPv4 = publicIPv4
    }
}

public struct ProcessorDetailInfo: Equatable {
    public var chipName: String
    public var totalCPUCores: Int
    public var performanceCores: Int
    public var efficiencyCores: Int
    public var gpuCores: Int?
    public var neuralEngine: String
    public var l1InstructionCache: String?
    public var l1DataCache: String?
    public var l2Cache: String?
    public var architecture: String

    public init(
        chipName: String,
        totalCPUCores: Int,
        performanceCores: Int,
        efficiencyCores: Int,
        gpuCores: Int? = nil,
        neuralEngine: String,
        l1InstructionCache: String? = nil,
        l1DataCache: String? = nil,
        l2Cache: String? = nil,
        architecture: String
    ) {
        self.chipName = chipName
        self.totalCPUCores = totalCPUCores
        self.performanceCores = performanceCores
        self.efficiencyCores = efficiencyCores
        self.gpuCores = gpuCores
        self.neuralEngine = neuralEngine
        self.l1InstructionCache = l1InstructionCache
        self.l1DataCache = l1DataCache
        self.l2Cache = l2Cache
        self.architecture = architecture
    }
}

public struct SecurityDetailInfo: Equatable {
    public var sipEnabled: Bool
    public var fileVaultEnabled: Bool
    public var gatekeeperEnabled: Bool
    public var secureBootStatus: String
    public var currentUser: String
    public var userHomeDirectory: String
    public var userShell: String

    public init(
        sipEnabled: Bool,
        fileVaultEnabled: Bool,
        gatekeeperEnabled: Bool,
        secureBootStatus: String,
        currentUser: String,
        userHomeDirectory: String,
        userShell: String
    ) {
        self.sipEnabled = sipEnabled
        self.fileVaultEnabled = fileVaultEnabled
        self.gatekeeperEnabled = gatekeeperEnabled
        self.secureBootStatus = secureBootStatus
        self.currentUser = currentUser
        self.userHomeDirectory = userHomeDirectory
        self.userShell = userShell
    }
}

public struct BatteryDetailInfo: Equatable {
    public let healthPercentage: Int?
    public let cycleCount: Int?
    public let currentPercentage: Int
    public let isCharging: Bool
    public let isACPowered: Bool
    public let chargingWattage: Int?

    public init(
        healthPercentage: Int?,
        cycleCount: Int?,
        currentPercentage: Int,
        isCharging: Bool,
        isACPowered: Bool,
        chargingWattage: Int? = nil
    ) {
        self.healthPercentage = healthPercentage
        self.cycleCount = cycleCount
        self.currentPercentage = currentPercentage
        self.isCharging = isCharging
        self.isACPowered = isACPowered
        self.chargingWattage = chargingWattage
    }
}

public struct SystemInfoReport: Equatable {
    public var machineName: String
    public var modelIdentifier: String
    public var serialNumber: String
    public var uptimeString: String

    public var osName: String
    public var osVersion: String
    public var osBuildNumber: String
    public var darwinKernel: String

    public var processor: ProcessorDetailInfo
    public var security: SecurityDetailInfo

    public var totalMemoryBytes: UInt64
    public var formattedMemory: String

    public var internalVolumes: [StorageVolumeInfo]
    public var externalVolumes: [StorageVolumeInfo]

    public var batteryInfo: BatteryDetailInfo?
    public var network: NetworkDetailInfo

    // MARK: - 快捷访问计算属性 (Convenience Accessors)
    public var chipName: String { processor.chipName }
    public var totalCores: Int { processor.totalCPUCores }
    public var performanceCores: Int { processor.performanceCores }
    public var efficiencyCores: Int { processor.efficiencyCores }
    public var architecture: String { processor.architecture }
    public var sipEnabled: Bool { security.sipEnabled }
    public var primaryIPv4: String { network.primaryIPv4 }
    public var macAddress: String { network.macAddress }
    public var wifiSSID: String? { network.wifiInfo?.ssid }
    public var defaultGateway: String? { network.defaultGateway }
    public var diskVolumeName: String { internalVolumes.first?.name ?? "Macintosh HD" }
    public var fileSystemType: String { internalVolumes.first?.fileSystem ?? "APFS" }
    public var diskTotalBytes: Int64 { internalVolumes.first?.totalBytes ?? 0 }
    public var diskAvailableBytes: Int64 { internalVolumes.first?.availableBytes ?? 0 }
    public var diskUsedBytes: Int64 { internalVolumes.first?.usedBytes ?? 0 }
    public var diskUsageRatio: Double { internalVolumes.first?.usageRatio ?? 0.0 }

    public init(
        machineName: String,
        modelIdentifier: String,
        serialNumber: String,
        uptimeString: String,
        osName: String,
        osVersion: String,
        osBuildNumber: String,
        darwinKernel: String,
        processor: ProcessorDetailInfo,
        security: SecurityDetailInfo,
        totalMemoryBytes: UInt64,
        formattedMemory: String,
        internalVolumes: [StorageVolumeInfo],
        externalVolumes: [StorageVolumeInfo] = [],
        batteryInfo: BatteryDetailInfo? = nil,
        network: NetworkDetailInfo
    ) {
        self.machineName = machineName
        self.modelIdentifier = modelIdentifier
        self.serialNumber = serialNumber
        self.uptimeString = uptimeString
        self.osName = osName
        self.osVersion = osVersion
        self.osBuildNumber = osBuildNumber
        self.darwinKernel = darwinKernel
        self.processor = processor
        self.security = security
        self.totalMemoryBytes = totalMemoryBytes
        self.formattedMemory = formattedMemory
        self.internalVolumes = internalVolumes
        self.externalVolumes = externalVolumes
        self.batteryInfo = batteryInfo
        self.network = network
    }

    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .decimal
        return formatter.string(fromByteCount: bytes)
    }

    public static func formatAdaptiveBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        if bytes < 1024 * 1024 {
            formatter.allowedUnits = [.useKB]
        } else if bytes < 1024 * 1024 * 1024 {
            formatter.allowedUnits = [.useMB]
        } else {
            formatter.allowedUnits = [.useGB, .useTB]
        }
        return formatter.string(fromByteCount: bytes)
    }

    public static func formatUptime(seconds: TimeInterval) -> String {
        let isZh = LocalizationService.shared.effectiveLanguage == .zhHans
        let totalSeconds = Int(seconds)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        if isZh {
            if days > 0 {
                return "\(days)天 \(hours)小时 \(minutes)分钟"
            } else if hours > 0 {
                return "\(hours)小时 \(minutes)分钟"
            } else {
                return "\(minutes)分钟"
            }
        } else {
            if days > 0 {
                return "\(days)d \(hours)h \(minutes)m"
            } else if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }
}
