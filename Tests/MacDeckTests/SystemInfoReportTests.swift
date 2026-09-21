import Testing
import Foundation
@testable import MacDeck

@Suite("SystemInfoReport Tests")
struct SystemInfoReportTests {
    @Test("Disk watermark level evaluation")
    func testDiskWatermarkLevelEvaluation() {
        #expect(DiskWatermarkLevel.evaluate(ratio: 0.50) == .healthy)
        #expect(DiskWatermarkLevel.evaluate(ratio: 0.74) == .healthy)
        #expect(DiskWatermarkLevel.evaluate(ratio: 0.75) == .warning)
        #expect(DiskWatermarkLevel.evaluate(ratio: 0.89) == .warning)
        #expect(DiskWatermarkLevel.evaluate(ratio: 0.90) == .danger)
        #expect(DiskWatermarkLevel.evaluate(ratio: 0.95) == .danger)
    }

    @Test("Byte formatting")
    func testByteFormatting() {
        #expect(SystemInfoReport.formatBytes(1_000_000_000) == "1 GB")
        #expect(SystemInfoReport.formatBytes(500_000_000_000) == "500 GB")
    }

    @Test("Uptime formatting")
    func testUptimeFormatting() {
        LocalizationService.shared.setLanguage(.zhHans)
        let uptimeString = SystemInfoReport.formatUptime(seconds: 180 + 3600 * 2 + 86400 * 3)
        #expect(uptimeString == "3天 2小时 3分钟")
    }

    @Test("Extended sub-models initialization")
    func testExtendedSubModels() {
        let storage = StorageVolumeInfo(
            name: "Samsung T7",
            mountPath: "/Volumes/Samsung T7",
            fileSystem: "ExFAT",
            totalBytes: 1_000_000_000_000,
            availableBytes: 600_000_000_000,
            usedBytes: 400_000_000_000,
            usageRatio: 0.4,
            isExternal: true,
            isRemovable: true
        )
        #expect(storage.isExternal)
        #expect(storage.id == "/Volumes/Samsung T7")

        let wifi = WiFiDetailInfo(
            ssid: "Office-5G",
            bssid: "A4:83:E7:00:11:22",
            band: "5 GHz",
            standard: "Wi-Fi 6 (802.11ax)",
            channel: 149,
            rssi: -48,
            transmitRateMbps: 1200.0
        )
        #expect(wifi.band == "5 GHz")
        #expect(wifi.rssi == -48)

        let processor = ProcessorDetailInfo(
            chipName: "Apple M3 Max",
            totalCPUCores: 16,
            performanceCores: 12,
            efficiencyCores: 4,
            gpuCores: 30,
            neuralEngine: "16 核神经网络引擎",
            l1InstructionCache: "128 KB",
            l1DataCache: "128 KB",
            l2Cache: "36 MB",
            architecture: "arm64"
        )
        #expect(processor.gpuCores == 30)

        let security = SecurityDetailInfo(
            sipEnabled: true,
            fileVaultEnabled: true,
            gatekeeperEnabled: true,
            secureBootStatus: "完整安全性",
            currentUser: "developer",
            userHomeDirectory: "/Users/developer",
            userShell: "/bin/zsh"
        )
        #expect(security.fileVaultEnabled)
        #expect(security.currentUser == "developer")

        let battery = BatteryDetailInfo(
            healthPercentage: 96,
            cycleCount: 86,
            currentPercentage: 92,
            isCharging: true,
            isACPowered: true,
            chargingWattage: 140
        )
        #expect(battery.chargingWattage == 140)
    }
}
