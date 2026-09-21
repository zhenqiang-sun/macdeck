import Testing
import Foundation
@testable import MacDeck

@Suite("SystemInfoService Tests")
struct SystemInfoServiceTests {
    @Test("Markdown report generation contains all sections and detailed parameters")
    func testGenerateMarkdownReport() {
        let processor = ProcessorDetailInfo(
            chipName: "Apple M3 Max",
            totalCPUCores: 16,
            performanceCores: 12,
            efficiencyCores: 4,
            gpuCores: 40,
            neuralEngine: "16 核神经网络引擎 (NPU)",
            l1InstructionCache: "128 KB",
            l1DataCache: "128 KB",
            l2Cache: "4 MB",
            architecture: "arm64"
        )

        let os = SecurityDetailInfo(
            sipEnabled: true,
            fileVaultEnabled: true,
            gatekeeperEnabled: true,
            secureBootStatus: "完全安全性",
            currentUser: "developer",
            userHomeDirectory: "/Users/developer",
            userShell: "/bin/zsh"
        )

        let internalVol = StorageVolumeInfo(
            name: "Macintosh HD",
            mountPath: "/",
            fileSystem: "APFS",
            totalBytes: 1000 * 1000 * 1000 * 1000,
            availableBytes: 320 * 1000 * 1000 * 1000,
            usedBytes: 680 * 1000 * 1000 * 1000,
            usageRatio: 0.68,
            isExternal: false,
            isRemovable: false
        )

        let externalVol = StorageVolumeInfo(
            name: "Extreme SSD",
            mountPath: "/Volumes/Extreme SSD",
            fileSystem: "APFS",
            totalBytes: 2000 * 1000 * 1000 * 1000,
            availableBytes: 1500 * 1000 * 1000 * 1000,
            usedBytes: 500 * 1000 * 1000 * 1000,
            usageRatio: 0.25,
            isExternal: true,
            isRemovable: true
        )

        let battery = BatteryDetailInfo(
            healthPercentage: 96,
            cycleCount: 86,
            currentPercentage: 92,
            isCharging: true,
            isACPowered: true,
            chargingWattage: 68
        )

        let wifi = WiFiDetailInfo(
            ssid: "Office-5G",
            bssid: "AA:BB:CC:DD:EE:FF",
            band: "5 GHz",
            standard: "Wi-Fi 6 (802.11ax)",
            channel: 36,
            rssi: -55,
            transmitRateMbps: 1200
        )

        let network = NetworkDetailInfo(
            primaryIPv4: "192.168.1.108",
            ipv6Global: "240e:390:xxxx:xxxx::1",
            ipv6LinkLocal: "fe80::1c32:45ef:fe78:9abc",
            macAddress: "A4:83:E7:00:11:22",
            defaultGateway: "192.168.1.1",
            dnsServers: ["192.168.1.1", "223.5.5.5"],
            wifiInfo: wifi,
            publicIPv4: "123.120.45.67"
        )

        let report = SystemInfoReport(
            machineName: "MacBook Pro (16-inch, 2023)",
            modelIdentifier: "Mac15,9",
            serialNumber: "C02TEST12345",
            uptimeString: "2天 4小时 10分钟",
            osName: "macOS",
            osVersion: "15.2",
            osBuildNumber: "24C101",
            darwinKernel: "Darwin 24.2.0",
            processor: processor,
            security: os,
            totalMemoryBytes: 36 * 1024 * 1024 * 1024,
            formattedMemory: "36 GB 统一内存",
            internalVolumes: [internalVol],
            externalVolumes: [externalVol],
            batteryInfo: battery,
            network: network
        )

        let markdown = SystemInfoService.shared.generateMarkdownReport(report: report)
        #expect(markdown.contains("MacBook Pro (16-inch, 2023)"))
        #expect(markdown.contains("Apple M3 Max"))
        #expect(markdown.contains("40 核心"))
        #expect(markdown.contains("16 核神经网络引擎 (NPU)"))
        #expect(markdown.contains("C02TEST12345"))
        #expect(markdown.contains("192.168.1.108"))
        #expect(markdown.contains("240e:390:xxxx:xxxx::1"))
        #expect(markdown.contains("fe80::1c32:45ef:fe78:9abc"))
        #expect(markdown.contains("123.120.45.67"))
        #expect(markdown.contains("macOS 15.2 (24C101)"))
        #expect(markdown.contains("Darwin 24.2.0"))
        #expect(markdown.contains("已启用"))
        #expect(markdown.contains("全盘硬件加密 (FileVault)**: 已开启 🔒"))
        #expect(markdown.contains("A4:83:E7:00:11:22"))
        #expect(markdown.contains("Office-5G"))
        #expect(markdown.contains("Extreme SSD"))
        #expect(markdown.contains("68 W"))
        #expect(markdown.contains("223.5.5.5"))
    }

    @Test("Live system info collection returns non-empty core data")
    func testLiveSystemInfoCollection() async {
        let report = await SystemInfoService.shared.collectSystemInfo()
        #expect(!report.machineName.isEmpty)
        #expect(!report.processor.chipName.isEmpty)
        #expect(report.processor.totalCPUCores > 0)
        #expect(report.totalMemoryBytes > 0)
        #expect(!report.internalVolumes.isEmpty)
        #expect(report.internalVolumes.first?.totalBytes ?? 0 > 0)
        #expect(!report.osVersion.isEmpty)
        #expect(!report.darwinKernel.isEmpty)
        #expect(!report.network.primaryIPv4.isEmpty)
    }
}


