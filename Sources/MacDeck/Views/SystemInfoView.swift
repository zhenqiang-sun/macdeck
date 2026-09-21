import SwiftUI

@MainActor
struct SystemInfoView: View {
    @ObservedObject private var vm: SystemInfoViewModel

    init() {
        self.vm = SystemInfoViewModel()
    }

    init(viewModel: SystemInfoViewModel) {
        self.vm = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DeckTheme.Spacing.lg) {
                if let report = vm.report {
                    // 顶部 Hero 状态卡片
                    HeroMachineCardView(report: report, vm: vm)

                    // 左右双列自适应平衡排版
                    HStack(alignment: .top, spacing: DeckTheme.Spacing.md) {
                        // 左列：Apple Silicon SoC 算力芯片、统一内存与电源电池
                        VStack(spacing: DeckTheme.Spacing.md) {
                            SoCCardView(report: report)
                            BatteryCardView(report: report)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)

                        // 右列：操作系统环境、存储卷档案与全栈网络通信
                        VStack(spacing: DeckTheme.Spacing.md) {
                            OSCardView(report: report)
                            StorageCardView(report: report)
                            NetworkCardView(report: report, vm: vm)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: DeckTheme.Spacing.md) {
                            ProgressView()
                                .controlSize(.regular)
                            Text("sysinfo.loading_hardware".localized)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 60)
                        Spacer()
                    }
                }
            }
            .padding(DeckTheme.Spacing.xl)
        }
        .task {
            await vm.loadInfo()
        }
    }
}

