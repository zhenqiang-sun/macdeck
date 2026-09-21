import Testing
import AppKit
@testable import MacDeck

@Suite("SystemInfoViewModel Tests")
@MainActor
struct SystemInfoViewModelTests {
    @Test("ViewModel initial state and loadInfo")
    func testViewModelLoad() async {
        let vm = SystemInfoViewModel()
        #expect(vm.report == nil)
        #expect(!vm.isLoading)

        await vm.loadInfo()
        #expect(vm.report != nil)
        #expect(!vm.isLoading)
    }

    @Test("ViewModel copyReport writes to pasteboard and shows feedback")
    func testCopyReport() async {
        let vm = SystemInfoViewModel()
        await vm.loadInfo()
        vm.copyReport()
        #expect(vm.copyFeedbackMessage == "已复制完整系统报告")

        let clipboardContent = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(clipboardContent.contains("# MacDeck 完整系统硬件与网络档案"))
    }

    @Test("ViewModel copySingleItem writes to pasteboard and shows feedback")
    func testCopySingleItem() {
        let vm = SystemInfoViewModel()
        vm.copySingleItem(title: "测试IP", value: "192.168.1.99")
        #expect(vm.copyFeedbackMessage == "已复制 测试IP")

        let clipboardContent = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(clipboardContent == "192.168.1.99")
    }

    @Test("ViewModel public IP probing state management")
    func testPublicIPProbing() async {
        let vm = SystemInfoViewModel()
        await vm.loadInfo()
        #expect(!vm.isProbingPublicIP)

        // 探测公网 IP
        await vm.fetchPublicIP()
        #expect(!vm.isProbingPublicIP)
        // 在有网络的环境下，report?.network.publicIPv4 将被填充，或若无外网则 publicIPProbeError 有提示
        if let ip = vm.report?.network.publicIPv4 {
            #expect(!ip.isEmpty)
        } else {
            #expect(vm.publicIPProbeError != nil)
        }
    }

    @Test("Extract valid IP from plain text, json and mixed responses")
    func testExtractValidIP() {
        #expect(SystemInfoViewModel.extractValidIP(from: "111.18.246.178\n") == "111.18.246.178")
        #expect(SystemInfoViewModel.extractValidIP(from: "{\"ip\":\"111.18.246.178\"}") == "111.18.246.178")
        #expect(SystemInfoViewModel.extractValidIP(from: "Your IP is 203.0.113.19 in Asia") == "203.0.113.19")
        #expect(SystemInfoViewModel.extractValidIP(from: "2409:8a70:f966:98a0:9561:f6e7:13a1:cc34") == "2409:8a70:f966:98a0:9561:f6e7:13a1:cc34")
        #expect(SystemInfoViewModel.extractValidIP(from: "invalid-response") == nil)
    }
}

