import XCTest
import SwiftUI
import AppKit
@testable import MacDeck

@MainActor
struct FakeMacWindow<Content: View>: View {
    let title: String
    let activeTab: NavigationItem
    let content: Content

    init(title: String = "MacDeck", activeTab: NavigationItem = .systemInfo, @ViewBuilder content: () -> Content) {
        self.title = title
        self.activeTab = activeTab
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏 Traffic Lights & Window Title
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 0.93, green: 0.42, blue: 0.37)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.96, green: 0.75, blue: 0.31)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.38, green: 0.77, blue: 0.33)).frame(width: 12, height: 12)
                }
                .padding(.leading, 14)

                Spacer()

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))

                Spacer()

                HStack { Spacer() }.frame(width: 50)
            }
            .frame(height: 38)
            .background(Color(red: 0.13, green: 0.14, blue: 0.17))

            Divider().background(Color.white.opacity(0.08))

            // 主体
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(NavigationItem.allCases) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 18)
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(item == activeTab ? Color.accentColor.opacity(0.2) : Color.clear)
                        .foregroundColor(item == activeTab ? .accentColor : Color.white.opacity(0.7))
                        .cornerRadius(6)
                    }

                    Spacer()

                    Text("nav.footer_author".localized)
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                }
                .padding(12)
                .frame(width: 190)
                .background(Color(red: 0.10, green: 0.11, blue: 0.13))

                Divider().background(Color.white.opacity(0.08))

                // Content
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 1080, height: 750)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

final class ShowcaseRendererTests: XCTestCase {
    @MainActor
    func testGenerateShowcaseScreenshots() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MacDeckTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // root
        
        let outputDir = projectRoot.appendingPathComponent("docs/images")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // 1. 英文版仪表盘
        LocalizationService.shared.setLanguage(.en)
        let vmEn = SystemInfoViewModel()
        vmEn.report = SystemInfoService.createDemoReport()
        let windowEn = FakeMacWindow(title: "MacDeck — System Dossier", activeTab: .systemInfo) {
            SystemInfoView(viewModel: vmEn)
                .padding(16)
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)

        if let pngEn = renderViewToPNG(view: windowEn, size: CGSize(width: 1080, height: 750)) {
            let fileURL = outputDir.appendingPathComponent("showcase-system-dossier-en.png")
            try pngEn.write(to: fileURL)
            print("✅ Exported: \(fileURL.path)")
        }

        // 2. 中文版仪表盘
        LocalizationService.shared.setLanguage(.zhHans)
        let vmZh = SystemInfoViewModel()
        vmZh.report = SystemInfoService.createDemoReport()
        let windowZh = FakeMacWindow(title: "MacDeck — 系统硬件与网络档案", activeTab: .systemInfo) {
            SystemInfoView(viewModel: vmZh)
                .padding(16)
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)

        if let pngZh = renderViewToPNG(view: windowZh, size: CGSize(width: 1080, height: 750)) {
            let fileURL = outputDir.appendingPathComponent("showcase-system-dossier-zh.png")
            try pngZh.write(to: fileURL)
            print("✅ Exported: \(fileURL.path)")
        }

        // 3. 中文版窗口归位界面
        LocalizationService.shared.setLanguage(.zhHans)
        let stateZh = AppState.createDemoState()
        let windowLayoutZh = FakeMacWindow(title: "MacDeck — 窗口归位与多屏管理", activeTab: .windowLayout) {
            MainWindowView(state: stateZh, selectedTab: .windowLayout).windowLayoutView
                .padding(16)
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)

        if let pngLayoutZh = renderViewToPNG(view: windowLayoutZh, size: CGSize(width: 1080, height: 750)) {
            let fileURL = outputDir.appendingPathComponent("showcase-window-restorer-zh.png")
            try pngLayoutZh.write(to: fileURL)
            print("✅ Exported: \(fileURL.path)")
        }

        // 4. 英文版窗口归位界面
        LocalizationService.shared.setLanguage(.en)
        let stateEn = AppState.createDemoState()
        let windowLayoutEn = FakeMacWindow(title: "MacDeck — Multi-Display Window Restoring", activeTab: .windowLayout) {
            MainWindowView(state: stateEn, selectedTab: .windowLayout).windowLayoutView
                .padding(16)
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)

        if let pngLayoutEn = renderViewToPNG(view: windowLayoutEn, size: CGSize(width: 1080, height: 750)) {
            let fileURL = outputDir.appendingPathComponent("showcase-window-restorer-en.png")
            try pngLayoutEn.write(to: fileURL)
            print("✅ Exported: \(fileURL.path)")
        }
    }

    @MainActor
    private func renderViewToPNG<V: View>(view: V, size: CGSize) -> Data? {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = CGColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        hostingView.layoutSubtreeIfNeeded()

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }
        rep.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }
}
