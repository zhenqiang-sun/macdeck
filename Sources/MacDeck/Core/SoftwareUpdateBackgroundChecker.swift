import Foundation
import Combine

@MainActor
public final class SoftwareUpdateBackgroundChecker: ObservableObject {
    public static let shared = SoftwareUpdateBackgroundChecker()

    @Published public var pendingUpdateCount: Int = 0
    @Published public var pendingUpdateItems: [SoftwarePackageItem] = []
    @Published public var isChecking: Bool = false

    private var timer: Timer?
    private let service: SoftwareUpdateService
    private let store: UpdateSettingsStore

    public init(
        service: SoftwareUpdateService = .shared,
        store: UpdateSettingsStore = .shared
    ) {
        self.service = service
        self.store = store
    }

    public func start() {
        // 1. 延迟 3 秒执行启动检查，保证应用主窗口快速呈现
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.store.shouldPerformAutoCheck() {
                    _ = await self.performSilentCheck()
                }
            }
        }

        // 2. 启动周期性定时器（每小时轮询一次判断是否需要检查）
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.store.shouldPerformAutoCheck() {
                    _ = await self.performSilentCheck()
                }
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    @discardableResult
    public func performSilentCheck() async -> [SoftwarePackageItem] {
        guard !isChecking else { return pendingUpdateItems }
        isChecking = true
        defer { isChecking = false }

        // 静默获取更新，不在终端控制台输出
        let found = await service.fetchOutdatedPackages { _ in }
        self.pendingUpdateItems = found
        self.pendingUpdateCount = found.count
        self.store.recordCheck(at: Date())

        return found
    }

    public func updatePendingCount(_ count: Int, items: [SoftwarePackageItem] = []) {
        self.pendingUpdateCount = count
        self.pendingUpdateItems = items
    }
}
