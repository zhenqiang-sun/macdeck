import Foundation

public enum CleanupTarget: Equatable {
    case all
    case single(CleanupItem)
}

public final class EnvironmentDoctorService {
    public static let shared = EnvironmentDoctorService()

    private let queue = DispatchQueue(label: "com.agy.MacDeck.environmentDoctor", qos: .userInitiated)

    public init() {}

    // MARK: - Diagnostics

    public func runAllDiagnostics(onOutput: @escaping (String) -> Void) async -> [DoctorItem] {
        var items: [DoctorItem] = []

        onOutput("==> 开始全面诊断本机开发环境健康状态 (共 5 项)...")

        // 1. Xcode CLT
        onOutput("==> [1/5] 正在体检 Xcode Command Line Tools...")
        let cltItem = await checkXcodeCLT()
        items.append(cltItem)
        logDoctorStatus(cltItem, onOutput: onOutput)

        // 2. Homebrew
        onOutput("==> [2/5] 正在体检 Homebrew 环境与健康状态 (brew doctor)...")
        let brewItem = await checkHomebrew()
        items.append(brewItem)
        logDoctorStatus(brewItem, onOutput: onOutput)

        // 3. Node & Volta
        onOutput("==> [3/5] 正在体检 Node.js / Volta / npm...")
        let nodeItem = await checkNodeAndVolta()
        items.append(nodeItem)
        logDoctorStatus(nodeItem, onOutput: onOutput)

        // 4. Python & pipx
        onOutput("==> [4/5] 正在体检 Python3 / pipx 虚拟环境...")
        let pythonItem = await checkPythonAndPipx()
        items.append(pythonItem)
        logDoctorStatus(pythonItem, onOutput: onOutput)

        // 5. Rust & Cargo
        onOutput("==> [5/5] 正在体检 Rust / Cargo 工具链...")
        let rustItem = await checkRustAndCargo()
        items.append(rustItem)
        logDoctorStatus(rustItem, onOutput: onOutput)

        onOutput("--------------------------------------------------")
        let warnings = items.filter { $0.status == .warning }.count
        let errors = items.filter { $0.status == .error }.count
        if errors > 0 {
            onOutput("❌ 体检结束：发现 \(errors) 项异常，\(warnings) 项警告，请根据建议修复")
        } else if warnings > 0 {
            onOutput("⚠️ 体检结束：环境可用，但存在 \(warnings) 项警告建议优化")
        } else {
            onOutput("✅ 体检结束：开发环境全部健康，状态优良！")
        }

        return items
    }

    private func logDoctorStatus(_ item: DoctorItem, onOutput: (String) -> Void) {
        switch item.status {
        case .healthy:
            onOutput("  ✓ \(item.title): \(item.summary)")
        case .warning:
            onOutput("  ! \(item.title): \(item.summary)")
            for d in item.details {
                onOutput("    • \(d)")
            }
            if let fix = item.fixCommand {
                onOutput("    💡 建议修复命令: \(fix)")
            }
        case .error:
            onOutput("  ✗ \(item.title): \(item.summary)")
            for d in item.details {
                onOutput("    • \(d)")
            }
            if let fix = item.fixCommand {
                onOutput("    💡 建议修复命令: \(fix)")
            }
        case .notInstalled:
            onOutput("  - \(item.title): 未安装")
        }
    }

    public func checkXcodeCLT() async -> DoctorItem {
        let selectPath = await executeShellCommand("xcode-select -p 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        if selectPath.isEmpty {
            return DoctorItem(
                id: "clt",
                title: "Xcode Command Line Tools",
                subtitle: "未找到路径",
                status: .error,
                summary: "未检测到 Command Line Tools 安装路径",
                details: ["系统缺少基本编译环境，可能导致 make/gcc/clang 无法使用"],
                fixCommand: "xcode-select --install"
            )
        }

        let clangCheck = await executeShellCommand("xcrun clang --version 2>/dev/null")
        if !clangCheck.contains("clang version") && !clangCheck.contains("Apple clang") {
            return DoctorItem(
                id: "clt",
                title: "Xcode Command Line Tools",
                subtitle: selectPath,
                status: .warning,
                summary: "CLT 路径已配置，但 clang 编译器响应异常",
                details: ["建议重置开发者目录：sudo xcode-select --reset"],
                fixCommand: "sudo xcode-select --reset"
            )
        }

        let pkgInfo = await executeShellCommand("pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null")
        var version = "已安装"
        for line in pkgInfo.components(separatedBy: .newlines) {
            if line.hasPrefix("version: ") {
                version = line.replacingOccurrences(of: "version: ", with: "").trimmingCharacters(in: .whitespaces)
                break
            }
        }

        return DoctorItem(
            id: "clt",
            title: "Xcode Command Line Tools",
            subtitle: "\(selectPath) (\(version))",
            status: .healthy,
            summary: "路径配置正确，底层 clang 编译工具链正常",
            details: []
        )
    }

    public func checkHomebrew() async -> DoctorItem {
        let whichBrew = await executeShellCommand("which brew 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        if whichBrew.isEmpty {
            return DoctorItem(
                id: "brew",
                title: "Homebrew",
                subtitle: "未安装",
                status: .notInstalled,
                summary: "系统未检测到 Homebrew",
                details: []
            )
        }

        let doctorOutput = await executeShellCommand("HOMEBREW_NO_AUTO_UPDATE=1 brew doctor 2>&1")
        let (status, summary, details, fix) = Self.parseBrewDoctor(output: doctorOutput)

        return DoctorItem(
            id: "brew",
            title: "Homebrew",
            subtitle: whichBrew,
            status: status,
            summary: summary,
            details: details,
            fixCommand: fix
        )
    }

    public func checkNodeAndVolta() async -> DoctorItem {
        let whichNode = await executeShellCommand("which node 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        let whichVolta = await executeShellCommand("which volta 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)

        if whichNode.isEmpty && whichVolta.isEmpty {
            return DoctorItem(
                id: "node",
                title: "Node.js & Volta",
                subtitle: "未安装",
                status: .notInstalled,
                summary: "系统未检测到 Node.js 运行时或 Volta 管理器",
                details: []
            )
        }

        var details: [String] = []
        var status: HealthStatus = .healthy
        var fix: String? = nil

        let nodeVer = await executeShellCommand("node -v 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)

        // 检查 Volta 与 Homebrew Node 是否存在 PATH 冲突
        if !whichVolta.isEmpty && whichNode.contains("/opt/homebrew/") {
            status = .warning
            details.append("同时检测到 Volta 与 Homebrew 安装的 Node，当前生效为 Homebrew: \(whichNode)")
            details.append("若希望 Volta 接管版本，请确保 ~/.volta/bin 在 PATH 中位于 /opt/homebrew/bin 前面")
            fix = "export PATH=\"$HOME/.volta/bin:$PATH\""
        }

        let subtitle = whichVolta.isEmpty ? "Node: \(nodeVer)" : "Volta 管理器 + Node: \(nodeVer)"
        let summary = status == .healthy ? "Node.js 运行时及 npm 路径正常" : "检测到 Node.js 环境存在路径竞争或潜在冲突"

        return DoctorItem(
            id: "node",
            title: "Node.js & Volta",
            subtitle: subtitle,
            status: status,
            summary: summary,
            details: details,
            fixCommand: fix
        )
    }

    public func checkPythonAndPipx() async -> DoctorItem {
        let whichPython = await executeShellCommand("which python3 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        if whichPython.isEmpty {
            return DoctorItem(
                id: "python",
                title: "Python3 & pipx",
                subtitle: "未安装",
                status: .notInstalled,
                summary: "未检测到 Python3 解释器",
                details: []
            )
        }

        let pyVer = await executeShellCommand("python3 --version 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        let whichPipx = await executeShellCommand("which pipx 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)

        var details: [String] = []
        var status: HealthStatus = .healthy

        if !whichPipx.isEmpty {
            let pipxList = await executeShellCommand("pipx list 2>/dev/null")
            if pipxList.contains("broken") || pipxList.contains("warning") {
                status = .warning
                details.append("pipx 虚拟环境存在潜在损坏或警告，建议运行 pipx reinstall-all")
            }
        }

        let subtitle = whichPipx.isEmpty ? pyVer : "\(pyVer) + pipx 工具"
        return DoctorItem(
            id: "python",
            title: "Python3 & pipx",
            subtitle: subtitle,
            status: status,
            summary: status == .healthy ? "Python3 环境正常" : "检测到 pipx 虚拟环境有警告",
            details: details,
            fixCommand: status == .warning ? "pipx reinstall-all" : nil
        )
    }

    public func checkRustAndCargo() async -> DoctorItem {
        let whichRustc = await executeShellCommand("which rustc 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        let whichCargo = await executeShellCommand("which cargo 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)

        if whichRustc.isEmpty && whichCargo.isEmpty {
            return DoctorItem(
                id: "rust",
                title: "Rust & Cargo",
                subtitle: "未安装",
                status: .notInstalled,
                summary: "未检测到 Rust / Cargo 工具链",
                details: []
            )
        }

        let rustVer = await executeShellCommand("rustc --version 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        return DoctorItem(
            id: "rust",
            title: "Rust & Cargo",
            subtitle: rustVer.isEmpty ? whichCargo : rustVer,
            status: .healthy,
            summary: "Rust 编译器与 Cargo 包管理器状态良好",
            details: []
        )
    }

    // MARK: - Brew Doctor Parser

    public static func parseBrewDoctor(output: String) -> (HealthStatus, String, [String], String?) {
        if output.contains("Your system is ready to brew.") {
            return (.healthy, "系统状态良好，无明显异常 (ready to brew)", [], nil)
        }

        var details: [String] = []
        var isError = false

        let lines = output.components(separatedBy: .newlines)
        var currentBlock: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Warning:") || trimmed.hasPrefix("Error:") {
                if trimmed.hasPrefix("Error:") { isError = true }
                if !currentBlock.isEmpty {
                    details.append(currentBlock.joined(separator: " "))
                    currentBlock.removeAll()
                }
                currentBlock.append(trimmed)
            } else if !currentBlock.isEmpty && !trimmed.isEmpty && !trimmed.hasPrefix("Please note that these warnings") {
                if currentBlock.count < 3 {
                    currentBlock.append(trimmed)
                }
            }
        }
        if !currentBlock.isEmpty {
            details.append(currentBlock.joined(separator: " "))
        }

        if isError {
            return (.error, "检测到 \(details.count) 项严重异常，请尽快排查", details, "brew update && brew upgrade")
        } else if !details.isEmpty {
            return (.warning, "检测到 \(details.count) 项警告建议关注", details, "brew cleanup")
        } else {
            return (.healthy, "Homebrew 运行正常", [], nil)
        }
    }

    // MARK: - Cleanup

    public func scanCleanupItems() async -> [CleanupItem] {
        var items: [CleanupItem] = [
            CleanupItem(id: "brew", name: "Homebrew 缓存与旧包", pathDescription: "~/Library/Caches/Homebrew", isScanning: true),
            CleanupItem(id: "npm", name: "npm 依赖缓存", pathDescription: "~/.npm", isScanning: true),
            CleanupItem(id: "pip", name: "Python pip 下载缓存", pathDescription: "~/Library/Caches/pip", isScanning: true),
            CleanupItem(id: "cargo", name: "Cargo 注册表下载包", pathDescription: "~/.cargo/registry/cache", isScanning: true)
        ]

        let home = FileManager.default.homeDirectoryForCurrentUser

        // 1. Brew
        let brewCacheURL = home.appendingPathComponent("Library/Caches/Homebrew")
        let brewSize = Self.calculateDirectorySize(url: brewCacheURL)
        items[0].sizeBytes = brewSize
        items[0].isScanning = false

        // 2. npm
        let npmCacheURL = home.appendingPathComponent(".npm")
        let npmSize = Self.calculateDirectorySize(url: npmCacheURL)
        items[1].sizeBytes = npmSize
        items[1].isScanning = false

        // 3. pip
        let pipCacheURL = home.appendingPathComponent("Library/Caches/pip")
        let pipSize = Self.calculateDirectorySize(url: pipCacheURL)
        items[2].sizeBytes = pipSize
        items[2].isScanning = false

        // 4. cargo
        let cargoCacheURL = home.appendingPathComponent(".cargo/registry/cache")
        let cargoSize = Self.calculateDirectorySize(url: cargoCacheURL)
        items[3].sizeBytes = cargoSize
        items[3].isScanning = false

        return items
    }

    public func buildCleanCommand(for item: CleanupItem) -> String {
        switch item.id {
        case "brew":
            return "HOMEBREW_NO_AUTO_UPDATE=1 brew cleanup -s --prune=all"
        case "npm":
            return "npm cache clean --force"
        case "pip":
            return "pip3 cache purge"
        case "cargo":
            return "rm -rf $HOME/.cargo/registry/cache/* 2>/dev/null || true"
        default:
            return ""
        }
    }

    public func cleanTarget(_ target: CleanupTarget, onOutput: @escaping (String) -> Void) async -> Bool {
        let toClean: [CleanupItem]
        switch target {
        case .all:
            toClean = await scanCleanupItems().filter { $0.sizeBytes > 0 }
        case .single(let item):
            toClean = [item]
        }

        if toClean.isEmpty {
            onOutput("✓ 没有需要清理的缓存项")
            return true
        }

        var allSuccess = true
        for (index, item) in toClean.enumerated() {
            let cmd = buildCleanCommand(for: item)
            guard !cmd.isEmpty else { continue }

            onOutput("\n--------------------------------------------------")
            onOutput("==> [\(index + 1)/\(toClean.count)] 正在清理 \(item.name)...")
            onOutput("$ \(cmd)")

            let code = await executeShellCommandStreaming(cmd, onOutput: onOutput)
            if code == 0 {
                onOutput("✓ \(item.name) 清理完成！")
            } else {
                onOutput("✗ \(item.name) 清理出现非零退出码 (\(code))")
                allSuccess = false
            }
        }

        onOutput("\n--------------------------------------------------")
        onOutput(allSuccess ? "✅ 缓存清理操作全部完成！" : "⚠️ 缓存清理结束，部分项目存在警告或未彻底清理")
        return allSuccess
    }

    public static func calculateDirectorySize(url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]),
                  resourceValues.isRegularFile == true else { continue }
            total += Int64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: - Shell execution

    private static var standardPathPrefix: String {
        let home = NSHomeDirectory()
        return "\(home)/.local/bin:\(home)/.cargo/bin:\(home)/.volta/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin"
    }

    private static func wrapCommand(_ command: String) -> String {
        let pathPrefix = Self.standardPathPrefix
        return """
        if [ -f "$HOME/.zshrc" ]; then
            source "$HOME/.zshrc" >/dev/null 2>&1
        fi
        export PATH="\(pathPrefix):$PATH"
        \(command)
        """
    }

    private func executeShellCommand(_ command: String) async -> String {
        let wrapped = Self.wrapCommand(command)
        return await withCheckedContinuation { continuation in
            queue.async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                var env = ProcessInfo.processInfo.environment
                let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
                env["PATH"] = "\(Self.standardPathPrefix):\(currentPath)"
                proc.environment = env
                proc.arguments = ["-l", "-c", wrapped]

                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe

                do {
                    try proc.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    let out = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: out)
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    private func executeShellCommandStreaming(_ command: String, onOutput: @escaping (String) -> Void) async -> Int32 {
        let wrapped = Self.wrapCommand(command)
        return await withCheckedContinuation { continuation in
            queue.async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                var env = ProcessInfo.processInfo.environment
                let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
                env["PATH"] = "\(Self.standardPathPrefix):\(currentPath)"
                proc.environment = env
                proc.arguments = ["-l", "-c", wrapped]

                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty, let line = String(data: data, encoding: .utf8) {
                        let trimmed = line.trimmingCharacters(in: .newlines)
                        if !trimmed.isEmpty {
                            onOutput(trimmed)
                        }
                    }
                }

                do {
                    try proc.run()
                    proc.waitUntilExit()
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: proc.terminationStatus)
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: -1)
                }
            }
        }
    }
}
