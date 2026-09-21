import Foundation
import SwiftUI
import AppKit

@MainActor
public final class SystemInfoViewModel: ObservableObject {
    @Published public var report: SystemInfoReport?
    @Published public var isLoading: Bool = false
    @Published public var isProbingPublicIP: Bool = false
    @Published public var publicIPProbeError: String? = nil
    @Published public var copyFeedbackMessage: String? = nil

    private var resetFeedbackTask: Task<Void, Never>?

    public init() {}

    public func loadInfo() async {
        guard !isLoading else { return }
        isLoading = true
        let data = await SystemInfoService.shared.collectSystemInfo()
        self.report = data
        self.isLoading = false
    }

    public func refresh() {
        Task {
            await loadInfo()
        }
    }

    public func fetchPublicIP() async {
        guard !isProbingPublicIP else { return }
        guard var currentReport = report else { return }
        isProbingPublicIP = true
        publicIPProbeError = nil

        defer {
            isProbingPublicIP = false
        }

        if let validIP = await Self.probePublicIP() {
            currentReport.network.publicIPv4 = validIP
            self.report = currentReport
        } else {
            publicIPProbeError = "网络探测超时或服务不可达"
        }
    }

    nonisolated public static func probePublicIP() async -> String? {
        let endpoints: [URL] = [
            URL(string: "https://icanhazip.com")!,
            URL(string: "https://ident.me")!,
            URL(string: "https://ipinfo.io/ip")!,
            URL(string: "https://myip.ipip.net/ip")!,
            URL(string: "https://api.ip.sb/ip")!,
            URL(string: "https://api.ipify.org")!
        ]

        return await withTaskGroup(of: String?.self) { group in
            for endpoint in endpoints {
                group.addTask {
                    do {
                        var request = URLRequest(url: endpoint)
                        request.timeoutInterval = 3.0
                        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                            return nil
                        }
                        guard let text = String(data: data, encoding: .utf8) else {
                            return nil
                        }
                        return extractValidIP(from: text)
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let ip = result, !ip.isEmpty {
                    group.cancelAll()
                    return ip
                }
            }
            return nil
        }
    }

    nonisolated public static func extractValidIP(from rawText: String) -> String? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 严格 IPv4 校验 (0.0.0.0 - 255.255.255.255)
        let strictIPv4 = #"^(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#
        if trimmed.range(of: strictIPv4, options: .regularExpression) != nil {
            return trimmed
        }

        // 2. 严格 IPv6 校验 (包含 : 且由十六进制与冒号组成)
        if trimmed.contains(":") && trimmed.count >= 3 && trimmed.count <= 45 {
            let strictIPv6 = #"^[0-9a-fA-F:]{3,45}$"#
            if trimmed.range(of: strictIPv6, options: .regularExpression) != nil {
                return trimmed
            }
        }

        // 3. 从 JSON 或富文本中提取包含的 IPv4
        let embeddedIPv4 = #"\b(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#
        if let match = trimmed.range(of: embeddedIPv4, options: .regularExpression) {
            return String(trimmed[match])
        }

        return nil
    }

    public func copyReport() {
        guard let report = report else { return }
        let markdown = SystemInfoService.shared.generateMarkdownReport(report: report)
        writeToPasteboard(markdown)
        triggerFeedback("已复制完整系统报告")
    }

    public func copySingleItem(title: String, value: String) {
        writeToPasteboard(value)
        triggerFeedback("已复制 \(title)")
    }

    private func writeToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func triggerFeedback(_ message: String) {
        copyFeedbackMessage = message
        resetFeedbackTask?.cancel()
        resetFeedbackTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                self.copyFeedbackMessage = nil
            }
        }
    }
}

