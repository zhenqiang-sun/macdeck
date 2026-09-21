import SwiftUI
import Combine
import UserNotifications

public enum ViewScope: String, CaseIterable, Identifiable {
    case updates = "可升级"
    case installed = "全部已安装"
    case history = "更新历史"
    public var id: String { rawValue }
}

@MainActor
public final class SoftwareUpdateViewModel: ObservableObject {
    @Published public var items: [SoftwarePackageItem] = []
    @Published public var installedItems: [SoftwarePackageItem] = []
    @Published public var currentScope: ViewScope = .updates

    @Published public var isChecking: Bool = false
    @Published public var isUpgrading: Bool = false
    @Published public var isScanningInstalled: Bool = false
    @Published public var isUninstalling: Bool = false

    @Published public var selectedFilter: PackageSource? = nil
    @Published public var searchQuery: String = ""
    @Published public var consoleLog: String = ""
    @Published public var isConsoleExpanded: Bool = false
    @Published public var statusMessage: String = "点击“检查可用更新”获取最新软件包列表"

    // 卸载确认弹窗
    @Published public var itemToUninstall: SoftwarePackageItem? = nil

    // 跨大版本确认弹窗
    @Published public var showMajorConfirmAlert: Bool = false
    @Published public var majorUpdateItems: [SoftwarePackageItem] = []
    private var pendingUpgradeItems: [SoftwarePackageItem] = []

    // 更新历史与审计
    @Published public var historyRecords: [UpdateHistoryRecord] = []
    @Published public var historySearchQuery: String = ""
    @Published public var historyStatusFilter: UpdateRecordStatus? = nil

    private let service: SoftwareUpdateService
    private let historyStore: UpdateHistoryStore

    public init(
        service: SoftwareUpdateService = .shared,
        historyStore: UpdateHistoryStore = .shared
    ) {
        self.service = service
        self.historyStore = historyStore
    }

    public var activeList: [SoftwarePackageItem] {
        get {
            switch currentScope {
            case .updates: return items
            case .installed: return installedItems
            case .history: return []
            }
        }
        set {
            switch currentScope {
            case .updates: items = newValue
            case .installed: installedItems = newValue
            case .history: break
            }
        }
    }

    public var filteredHistoryRecords: [UpdateHistoryRecord] {
        historyRecords.filter { record in
            let matchesSearch: Bool
            let q = historySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if q.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = record.packageName.lowercased().contains(q) ||
                                record.packageId.lowercased().contains(q) ||
                                record.previousVersion.lowercased().contains(q) ||
                                record.targetVersion.lowercased().contains(q)
            }
            let matchesStatus: Bool
            if let status = historyStatusFilter {
                matchesStatus = record.status == status
            } else {
                matchesStatus = true
            }
            let matchesSource: Bool
            if let filter = selectedFilter {
                matchesSource = record.source == filter
            } else {
                matchesSource = true
            }
            return matchesSearch && matchesStatus && matchesSource
        }
    }

    public func loadHistory() {
        historyRecords = historyStore.loadRecords()
    }

    public func clearHistory() {
        historyStore.clearHistory()
        historyRecords = []
    }

    public func exportHistoryJSON() -> String {
        historyStore.exportJSON()
    }

    public func exportHistoryCSV() -> String {
        historyStore.exportCSV()
    }

    public var filteredItems: [SoftwarePackageItem] {
        activeList.filter { item in
            if let filter = selectedFilter, item.source != filter {
                return false
            }
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                let nameMatch = item.displayName.lowercased().contains(q) || item.rawName.lowercased().contains(q)
                if !nameMatch { return false }
            }
            return true
        }
    }

    public var selectedItemsCount: Int {
        filteredItems.filter { $0.isSelected }.count
    }

    public var allSelected: Bool {
        !filteredItems.isEmpty && filteredItems.allSatisfy { $0.isSelected }
    }

    public func toggleSelectAll() {
        let target = !allSelected
        for i in 0..<items.count {
            if selectedFilter == nil || items[i].source == selectedFilter {
                items[i].isSelected = target
            }
        }
    }

    public func appendConsole(_ text: String) {
        consoleLog += text
        if !text.hasSuffix("\n") {
            consoleLog += "\n"
        }
    }

    public func checkUpdates() {
        guard !isChecking && !isUpgrading else { return }
        isChecking = true
        statusMessage = "正在检测系统与开发工具链可用更新..."
        consoleLog = ""
        isConsoleExpanded = true

        Task { [weak self] in
            guard let self = self else { return }
            let found = await self.service.fetchOutdatedPackages { [weak self] line in
                Task { @MainActor in
                    self?.appendConsole(line)
                }
            }
            self.items = found
            SoftwareUpdateBackgroundChecker.shared.updatePendingCount(found.count, items: found)
            self.isChecking = false
            self.statusMessage = found.isEmpty ? "所有软件与工具链均为最新状态！" : "发现 \(found.count) 项可用更新"
            // 检查完成后自动折叠终端，将空间还给列表
            withAnimation(.spring()) {
                self.isConsoleExpanded = false
            }

            // 如果已安装列表为空，顺便后台扫描一次
            if self.installedItems.isEmpty {
                self.scanInstalledSilently()
            }
        }
    }

    public func scanInstalled() {
        guard !isScanningInstalled else { return }
        isScanningInstalled = true
        statusMessage = "正在扫描本机全部已安装软件与工具..."
        isConsoleExpanded = false

        Task { [weak self] in
            guard let self = self else { return }
            let found = await self.service.fetchInstalledPackages(outdatedItems: self.items) { [weak self] line in
                Task { @MainActor in
                    self?.appendConsole(line)
                }
            }
            self.installedItems = found
            self.isScanningInstalled = false
            self.statusMessage = "共发现 \(found.count) 项已安装软件与工具"
        }
    }

    private func scanInstalledSilently() {
        Task {
            let found = await service.fetchInstalledPackages(outdatedItems: self.items) { _ in }
            self.installedItems = found
        }
    }

    public func upgradeSingle(item: SoftwarePackageItem) {
        guard !isUpgrading else { return }
        if item.isMajorUpdate {
            majorUpdateItems = [item]
            pendingUpgradeItems = [item]
            showMajorConfirmAlert = true
            return
        }
        executeUpgrade(items: [item])
    }

    public func upgradeSelected() {
        guard !isUpgrading else { return }
        let toUpgrade = items.filter { $0.isSelected && $0.status != .upgraded }
        guard !toUpgrade.isEmpty else { return }

        let majorItems = toUpgrade.filter { $0.isMajorUpdate }
        if !majorItems.isEmpty {
            majorUpdateItems = majorItems
            pendingUpgradeItems = toUpgrade
            showMajorConfirmAlert = true
            return
        }
        executeUpgrade(items: toUpgrade)
    }

    public func confirmMajorUpgrade() {
        showMajorConfirmAlert = false
        let toUpgrade = pendingUpgradeItems
        pendingUpgradeItems = []
        majorUpdateItems = []
        executeUpgrade(items: toUpgrade)
    }

    private func executeUpgrade(items toUpgrade: [SoftwarePackageItem]) {
        guard !toUpgrade.isEmpty else { return }
        isUpgrading = true
        isConsoleExpanded = true

        for item in toUpgrade {
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].status = .upgrading
            }
        }

        let batches = service.buildBatchUpgradeCommands(for: toUpgrade)
        statusMessage = "正在升级 \(toUpgrade.count) 项软件..."

        Task { [weak self] in
            guard let self = self else { return }
            var successCount = 0
            var failureCount = 0

            for (idx, batch) in batches.enumerated() {
                let baseTitle = batch.items.count == 1
                    ? batch.items[0].displayName
                    : "\(batch.items.first?.source.displayName ?? "批量") (\(batch.items.count) 项: \(batch.items.map { $0.displayName }.joined(separator: ", ")))"

                let displayTitle = batches.count > 1 ? "[\(idx + 1)/\(batches.count)] \(baseTitle)" : baseTitle

                let success = await self.service.upgradeBatch(
                    command: batch.command,
                    displayTitle: displayTitle
                ) { [weak self] line in
                    Task { @MainActor [weak self] in
                        self?.appendConsole(line)
                    }
                }

                if success {
                    successCount += batch.items.count
                } else {
                    failureCount += batch.items.count
                }

                for item in batch.items {
                    if let idx = self.items.firstIndex(where: { $0.id == item.id }) {
                        self.items[idx].status = success ? .upgraded : .failed(message: "升级失败")
                    }
                    if let insIdx = self.installedItems.firstIndex(where: { $0.id == item.id }) {
                        self.installedItems[insIdx].currentVersion = item.latestVersion
                        self.installedItems[insIdx].status = success ? .upgraded : .failed(message: "升级失败")
                    }
                }

                // 记录审计历史
                var newHistoryRecords: [UpdateHistoryRecord] = []
                for item in batch.items {
                    let record = UpdateHistoryRecord(
                        packageId: item.id,
                        packageName: item.displayName,
                        source: item.source,
                        previousVersion: item.currentVersion,
                        targetVersion: item.latestVersion,
                        status: success ? .success : .failed,
                        command: batch.command,
                        outputLog: self.consoleLog,
                        rollbackHint: RollbackHelper.generateHint(source: item.source, name: item.rawName, previousVersion: item.currentVersion)
                    )
                    newHistoryRecords.append(record)
                }
                self.historyStore.addRecords(newHistoryRecords)
                if self.currentScope == .history {
                    self.loadHistory()
                }
            }

            self.isUpgrading = false
            let remaining = self.items.filter { $0.status != .upgraded }.count
            SoftwareUpdateBackgroundChecker.shared.updatePendingCount(remaining)
            self.statusMessage = failureCount == 0 ? "全部升级完成！(成功 \(successCount) 项)" : "升级结束：成功 \(successCount) 项，失败 \(failureCount) 项"
            self.sendCompletionNotification(successCount: successCount, failureCount: failureCount)
        }
    }

    private func sendCompletionNotification(successCount: Int, failureCount: Int) {
        let title = "MacDeck 软件更新"
        let body = failureCount == 0
            ? "已成功完成 \(successCount) 项软件的升级！"
            : "软件升级完成：成功 \(successCount) 项，失败 \(failureCount) 项，请查看日志。"

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }

    public func requestUninstall(item: SoftwarePackageItem) {
        itemToUninstall = item
    }

    public func confirmUninstall() {
        guard let item = itemToUninstall else { return }
        itemToUninstall = nil
        isUninstalling = true
        isConsoleExpanded = true
        statusMessage = "正在卸载 \(item.displayName)..."

        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.service.uninstallPackage(item) { [weak self] line in
                Task { @MainActor in
                    self?.appendConsole(line)
                }
            }
            if success {
                self.installedItems.removeAll { $0.id == item.id }
                self.items.removeAll { $0.id == item.id }
                let remaining = self.items.filter { $0.status != .upgraded }.count
                SoftwareUpdateBackgroundChecker.shared.updatePendingCount(remaining)
                self.statusMessage = "已成功卸载 \(item.displayName)"
            } else {
                self.statusMessage = "卸载 \(item.displayName) 失败，详见日志"
            }
            self.isUninstalling = false
        }
    }

    public func cancel() {
        service.cancel()
        isUpgrading = false
        isChecking = false
        isUninstalling = false
        isScanningInstalled = false
        appendConsole("\n⚠️ 用户已中止任务")
    }

    public func openLogFile() {
        NSWorkspace.shared.selectFile(service.logFileURL.path, inFileViewerRootedAtPath: "")
    }
}
