import SwiftUI
import Combine

@MainActor
public final class EnvironmentMaintenanceViewModel: ObservableObject {
    @Published public var doctorItems: [DoctorItem] = []
    @Published public var cleanupItems: [CleanupItem] = []

    @Published public var isDiagnosing: Bool = false
    @Published public var isScanningCache: Bool = false
    @Published public var isCleaning: Bool = false

    @Published public var statusMessage: String = "就绪"
    @Published public var consoleLog: String = ""
    @Published public var isConsoleExpanded: Bool = false

    @Published public var showCleanConfirmationAlert: Bool = false
    @Published public var pendingCleanTarget: CleanupTarget = .all

    private let service: EnvironmentDoctorService

    public init(service: EnvironmentDoctorService = .shared) {
        self.service = service
    }

    public var totalCleanableBytes: Int64 {
        cleanupItems.reduce(0) { $0 + $1.sizeBytes }
    }

    public var formattedTotalCleanable: String {
        if totalCleanableBytes == 0 { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalCleanableBytes)
    }

    public var overallHealth: HealthStatus {
        if doctorItems.contains(where: { $0.status == .error }) { return .error }
        if doctorItems.contains(where: { $0.status == .warning }) { return .warning }
        return .healthy
    }

    public func appendConsole(_ text: String) {
        consoleLog += text
        if !text.hasSuffix("\n") {
            consoleLog += "\n"
        }
    }

    public func runDiagnosis() {
        guard !isDiagnosing else { return }
        isDiagnosing = true
        statusMessage = "正在体检开发环境..."
        consoleLog = ""
        isConsoleExpanded = true

        Task { [weak self] in
            guard let self = self else { return }
            let items = await self.service.runAllDiagnostics { [weak self] line in
                Task { @MainActor in
                    self?.appendConsole(line)
                }
            }
            self.doctorItems = items
            self.isDiagnosing = false
            let warnings = items.filter { $0.status == .warning }.count
            let errors = items.filter { $0.status == .error }.count
            if errors > 0 {
                self.statusMessage = "体检发现 \(errors) 项异常与 \(warnings) 项警告"
            } else if warnings > 0 {
                self.statusMessage = "体检发现 \(warnings) 项警告建议关注"
            } else {
                self.statusMessage = "开发环境全部健康！"
            }
            withAnimation(.spring()) {
                self.isConsoleExpanded = false
            }
        }
    }

    public func scanCacheSizes() {
        guard !isScanningCache else { return }
        isScanningCache = true

        Task { [weak self] in
            guard let self = self else { return }
            let items = await self.service.scanCleanupItems()
            self.cleanupItems = items
            self.isScanningCache = false
        }
    }

    public func requestClean(target: CleanupTarget) {
        pendingCleanTarget = target
        showCleanConfirmationAlert = true
    }

    public func confirmClean() {
        showCleanConfirmationAlert = false
        guard !isCleaning else { return }
        isCleaning = true
        statusMessage = "正在执行缓存清理..."
        isConsoleExpanded = true

        let target = pendingCleanTarget
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.service.cleanTarget(target) { [weak self] line in
                Task { @MainActor in
                    self?.appendConsole(line)
                }
            }
            self.isCleaning = false
            self.statusMessage = success ? "缓存清理完成！" : "部分缓存未能彻底清理，请查看日志"
            self.scanCacheSizes()
        }
    }
}
