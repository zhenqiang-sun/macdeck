import Foundation

public final class SoftwareUpdateService: @unchecked Sendable {
    public static let shared = SoftwareUpdateService()

    public var logFileURL: URL {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
            .appendingPathComponent("MacDeck")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir.appendingPathComponent("software-update.log")
    }

    public var askpassURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacDeck")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let scriptURL = appSupport.appendingPathComponent("askpass.sh")
        let scriptContent = """
        #!/bin/bash
        raw_prompt="${1:-请输入管理员密码以继续升级：}"
        msg="MacDeck 正在执行系统权限操作（例如 Docker Desktop 等软件的系统组件更新与清理）。

        ${raw_prompt}"
        /usr/bin/osascript - "$msg" 2>/dev/null <<'EOF'
        on run argv
            set promptText to item 1 of argv
            tell application "System Events"
                activate
                set pwd to text returned of (display dialog promptText default answer "" with hidden answer with icon caution with title "MacDeck 权限授权")
            end tell
            return pwd
        end run
        EOF
        """
        if !FileManager.default.fileExists(atPath: scriptURL.path) ||
           (try? String(contentsOf: scriptURL, encoding: .utf8)) != scriptContent {
            try? scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        }
        return scriptURL
    }

    private var currentProcess: Process?
    private let queue = DispatchQueue(label: "com.macdeck.update-service", qos: .userInitiated)

    public init() {}

    public func buildUpgradeCommand(for item: SoftwarePackageItem) -> String {
        switch item.source {
        case .brewCask:
            return "brew upgrade --cask \(item.rawName)"
        case .brewFormula:
            return "brew upgrade \(item.rawName)"
        case .npmGlobal:
            return "npm install -g \(item.rawName)@latest"
        case .appStore:
            return "mas upgrade \(item.rawName)"
        case .pipx:
            return "pipx upgrade \(item.rawName)"
        case .cargo:
            return "cargo install \(item.rawName)"
        case .volta:
            return "volta install \(item.rawName)@latest"
        }
    }

    public func buildBatchUpgradeCommands(for items: [SoftwarePackageItem]) -> [(command: String, items: [SoftwarePackageItem])] {
        var results: [(command: String, items: [SoftwarePackageItem])] = []

        // 1. Group brewFormula
        let formulae = items.filter { $0.source == .brewFormula }
        if !formulae.isEmpty {
            let names = formulae.map { $0.rawName }.joined(separator: " ")
            results.append((command: "brew upgrade \(names)", items: formulae))
        }

        // 2. Group brewCask
        let casks = items.filter { $0.source == .brewCask }
        if !casks.isEmpty {
            let names = casks.map { $0.rawName }.joined(separator: " ")
            results.append((command: "brew upgrade --cask \(names)", items: casks))
        }

        // 3. Other sources (npm, volta, mas, pipx, cargo) execute per-item
        let others = items.filter { $0.source != .brewFormula && $0.source != .brewCask }
        for item in others {
            results.append((command: buildUpgradeCommand(for: item), items: [item]))
        }

        return results
    }

    public func buildUninstallCommand(for item: SoftwarePackageItem) -> String {
        switch item.source {
        case .brewCask:
            return "brew uninstall --cask \(item.rawName)"
        case .brewFormula:
            return "brew uninstall \(item.rawName)"
        case .npmGlobal:
            return "npm uninstall -g \(item.rawName)"
        case .appStore:
            return "echo '请前往“访达”或“启动台”长按移除 \(item.displayName)'"
        case .pipx:
            return "pipx uninstall \(item.rawName)"
        case .cargo:
            return "cargo uninstall \(item.rawName)"
        case .volta:
            return "volta uninstall \(item.rawName)"
        }
    }

    public func fetchOutdatedPackages(onOutput: @escaping (String) -> Void) async -> [SoftwarePackageItem] {
        var items: [SoftwarePackageItem] = []

        var checkSteps: [(name: String, title: String, check: () async -> [SoftwarePackageItem])] = []

        let whichBrew = await executeShellCommand("which brew 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichBrew.isEmpty {
            checkSteps.append((
                name: "Homebrew",
                title: "Homebrew (Formula + Cask)",
                check: { [self] in
                    let brewOut = await executeShellCommand("HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --json=v2 2>/dev/null", streamOutput: false)
                    return PackageParsers.parseBrewOutdated(jsonString: brewOut).filter {
                        !UpdateSettingsStore.shared.shouldSkipUpdate(rawName: $0.rawName, latestVersion: $0.latestVersion)
                    }
                }
            ))
        }

        let whichNpm = await executeShellCommand("which npm 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichNpm.isEmpty {
            checkSteps.append((
                name: "npm",
                title: "npm 全局模块",
                check: { [self] in
                    let npmOut = await executeShellCommand("npm -g outdated --json 2>/dev/null", streamOutput: false)
                    return PackageParsers.parseNpmOutdated(jsonString: npmOut).filter {
                        !UpdateSettingsStore.shared.shouldSkipUpdate(rawName: $0.rawName, latestVersion: $0.latestVersion)
                    }
                }
            ))
        }

        let whichMas = await executeShellCommand("which mas 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichMas.isEmpty {
            checkSteps.append((
                name: "Mac App Store",
                title: "Mac App Store 应用",
                check: { [self] in
                    let masOut = await executeShellCommand("mas outdated 2>/dev/null", streamOutput: false)
                    return PackageParsers.parseMasOutdated(outputString: masOut).filter {
                        !UpdateSettingsStore.shared.shouldSkipUpdate(rawName: $0.rawName, latestVersion: $0.latestVersion)
                    }
                }
            ))
        }

        let whichVolta = await executeShellCommand("which volta 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichVolta.isEmpty {
            checkSteps.append((
                name: "Volta",
                title: "Volta 全局工具包",
                check: { [self] in
                    let voltaOut = await executeShellCommand("volta list all 2>/dev/null", streamOutput: false)
                    let installedVolta = PackageParsers.parseInstalledVolta(output: voltaOut)
                    return await withTaskGroup(of: SoftwarePackageItem?.self) { group in
                        for pkg in installedVolta {
                            group.addTask { [self] in
                                let latestVer = await self.executeShellCommand("npm view \(pkg.rawName) version 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
                                if !latestVer.isEmpty && latestVer != pkg.currentVersion && !UpdateSettingsStore.shared.shouldSkipUpdate(rawName: pkg.rawName, latestVersion: latestVer) {
                                    return SoftwarePackageItem(
                                        id: pkg.id,
                                        rawName: pkg.rawName,
                                        displayName: pkg.displayName,
                                        currentVersion: pkg.currentVersion,
                                        latestVersion: latestVer,
                                        source: .volta
                                    )
                                }
                                return nil
                            }
                        }
                        var results: [SoftwarePackageItem] = []
                        for await item in group {
                            if let item = item {
                                results.append(item)
                            }
                        }
                        return results.sorted { $0.displayName < $1.displayName }
                    }
                }
            ))
        }

        let whichPipx = await executeShellCommand("which pipx 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichPipx.isEmpty {
            checkSteps.append((
                name: "pipx",
                title: "pipx (Python 工具)",
                check: { [self] in
                    let pipxOut = await executeShellCommand("pipx list --json 2>/dev/null", streamOutput: false)
                    let installedPipx = PackageParsers.parseInstalledPipx(jsonString: pipxOut)
                    return await withTaskGroup(of: SoftwarePackageItem?.self) { group in
                        for pkg in installedPipx {
                            group.addTask { [self] in
                                let pypiJson = await self.executeShellCommand("curl -s --max-time 3 https://pypi.org/pypi/\(pkg.rawName)/json 2>/dev/null", streamOutput: false)
                                if let data = pypiJson.data(using: .utf8),
                                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let info = dict["info"] as? [String: Any],
                                   let latestVer = info["version"] as? String,
                                   !latestVer.isEmpty && latestVer != pkg.currentVersion && !UpdateSettingsStore.shared.shouldSkipUpdate(rawName: pkg.rawName, latestVersion: latestVer) {
                                    return SoftwarePackageItem(
                                        id: pkg.id,
                                        rawName: pkg.rawName,
                                        displayName: pkg.displayName,
                                        currentVersion: pkg.currentVersion,
                                        latestVersion: latestVer,
                                        source: .pipx
                                    )
                                }
                                return nil
                            }
                        }
                        var results: [SoftwarePackageItem] = []
                        for await item in group {
                            if let item = item {
                                results.append(item)
                            }
                        }
                        return results.sorted { $0.displayName < $1.displayName }
                    }
                }
            ))
        }

        let whichCargo = await executeShellCommand("which cargo 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichCargo.isEmpty {
            checkSteps.append((
                name: "Cargo",
                title: "Cargo (Rust 工具)",
                check: { [self] in
                    let whichCargoUpdate = await executeShellCommand("which cargo-install-update 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
                    var cargoOutdated: [SoftwarePackageItem] = []
                    if !whichCargoUpdate.isEmpty {
                        let cargoUpdateOut = await executeShellCommand("cargo install-update -l 2>/dev/null", streamOutput: false)
                        cargoOutdated = PackageParsers.parseCargoInstallUpdateList(output: cargoUpdateOut).filter {
                            !UpdateSettingsStore.shared.shouldSkipUpdate(rawName: $0.rawName, latestVersion: $0.latestVersion)
                        }
                    } else {
                        let listOut = await executeShellCommand("cargo install --list 2>/dev/null", streamOutput: false)
                        let installedCargo = PackageParsers.parseInstalledCargo(output: listOut)
                        cargoOutdated = await withTaskGroup(of: SoftwarePackageItem?.self) { group in
                            for pkg in installedCargo {
                                group.addTask { [self] in
                                    let crateJson = await self.executeShellCommand("curl -s --max-time 3 -H 'User-Agent: MacDeck/1.1.0' https://crates.io/api/v1/crates/\(pkg.rawName) 2>/dev/null", streamOutput: false)
                                    if let data = crateJson.data(using: .utf8),
                                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                       let cr = dict["crate"] as? [String: Any],
                                       let latestVer = cr["max_version"] as? String,
                                       !latestVer.isEmpty && latestVer != pkg.currentVersion && !UpdateSettingsStore.shared.shouldSkipUpdate(rawName: pkg.rawName, latestVersion: latestVer) {
                                        return SoftwarePackageItem(
                                            id: pkg.id,
                                            rawName: pkg.rawName,
                                            displayName: pkg.displayName,
                                            currentVersion: pkg.currentVersion,
                                            latestVersion: latestVer,
                                            source: .cargo
                                        )
                                    }
                                    return nil
                                }
                            }
                            var results: [SoftwarePackageItem] = []
                            for await item in group {
                                if let item = item {
                                    results.append(item)
                                }
                            }
                            return results.sorted { $0.displayName < $1.displayName }
                        }
                    }
                    return cargoOutdated
                }
            ))
        }

        let totalSteps = checkSteps.count
        if totalSteps == 0 {
            onOutput("⚠️ 未检测到任何受支持的包管理工具 (Homebrew / npm / mas / volta / pipx / cargo)")
            onOutput("✅ 检查完毕：共发现 0 项可用更新")
            return []
        }

        for (index, step) in checkSteps.enumerated() {
            let stepNum = index + 1
            onOutput("==> [\(stepNum)/\(totalSteps)] 检查 \(step.title) 可用更新...")
            let found = await step.check()
            items.append(contentsOf: found)
            if found.isEmpty {
                onOutput("  ✓ \(step.name) 已是最新 (0 项更新)")
            } else {
                onOutput("  ✓ \(step.name) 检测到 \(found.count) 项可用更新")
            }
        }

        onOutput("--------------------------------------------------")
        onOutput("✅ 检查完毕：共发现 \(items.count) 项可用更新")
        return items
    }

    public func upgradePackage(_ item: SoftwarePackageItem, onOutput: @escaping (String) -> Void) async -> Bool {
        let cmd = buildUpgradeCommand(for: item)
        onOutput("\n--------------------------------------------------")
        onOutput("==> 正在升级 \(item.displayName) (\(item.currentVersion) ➔ \(item.latestVersion))...")
        onOutput("$ \(cmd)")

        appendLog("\n[\(ISO8601DateFormatter().string(from: Date()))] UPGRADE \(item.displayName): $ \(cmd)\n")

        let code = await executeShellCommandWithStreaming(cmd, onOutput: onOutput)
        if code == 0 {
            onOutput("✓ \(item.displayName) 升级成功！")
            appendLog("✓ \(item.displayName) SUCCESS\n")
            return true
        } else {
            onOutput("✗ \(item.displayName) 升级失败 (退出码 \(code))")
            appendLog("✗ \(item.displayName) FAILED with code \(code)\n")
            return false
        }
    }

    public func upgradeBatch(command: String, displayTitle: String, onOutput: @escaping (String) -> Void) async -> Bool {
        onOutput("\n--------------------------------------------------")
        onOutput("==> 正在升级: \(displayTitle)...")
        onOutput("$ \(command)")

        appendLog("\n[\(ISO8601DateFormatter().string(from: Date()))] BATCH UPGRADE \(displayTitle): $ \(command)\n")

        let code = await executeShellCommandWithStreaming(command, onOutput: onOutput)
        if code == 0 {
            onOutput("✓ \(displayTitle) 升级成功！")
            appendLog("✓ \(displayTitle) SUCCESS\n")
            return true
        } else {
            onOutput("✗ \(displayTitle) 升级失败或部分失败 (退出码 \(code))")
            appendLog("✗ \(displayTitle) FAILED with code \(code)\n")
            return false
        }
    }

    public func uninstallPackage(_ item: SoftwarePackageItem, onOutput: @escaping (String) -> Void) async -> Bool {
        let cmd = buildUninstallCommand(for: item)
        onOutput("\n--------------------------------------------------")
        onOutput("==> 正在卸载 \(item.displayName)...")
        onOutput("$ \(cmd)")

        appendLog("\n[\(ISO8601DateFormatter().string(from: Date()))] UNINSTALL \(item.displayName): $ \(cmd)\n")

        let code = await executeShellCommandWithStreaming(cmd, onOutput: onOutput)
        if code == 0 {
            onOutput("✓ \(item.displayName) 卸载完成！")
            appendLog("✓ \(item.displayName) UNINSTALL SUCCESS\n")
            return true
        } else {
            onOutput("✗ \(item.displayName) 卸载失败 (退出码 \(code))")
            appendLog("✗ \(item.displayName) UNINSTALL FAILED with code \(code)\n")
            return false
        }
    }

    public func fetchInstalledPackages(outdatedItems: [SoftwarePackageItem] = [], onOutput: @escaping (String) -> Void) async -> [SoftwarePackageItem] {
        var items: [SoftwarePackageItem] = []
        var outdatedMap: [String: String] = [:]
        for o in outdatedItems {
            outdatedMap[o.rawName] = o.latestVersion
        }

        var scanSteps: [(name: String, title: String, scan: () async -> [SoftwarePackageItem])] = []

        let whichBrew = await executeShellCommand("which brew 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichBrew.isEmpty {
            scanSteps.append((
                name: "Homebrew",
                title: "Homebrew (Formula + Cask)",
                scan: { [self] in
                    let casksOut = await executeShellCommand("HOMEBREW_NO_AUTO_UPDATE=1 brew list --cask 2>/dev/null", streamOutput: false)
                    let formulaeOut = await executeShellCommand("HOMEBREW_NO_AUTO_UPDATE=1 brew list --formula 2>/dev/null", streamOutput: false)
                    return PackageParsers.parseInstalledBrew(casksOutput: casksOut, formulaeOutput: formulaeOut, outdatedMap: outdatedMap)
                }
            ))
        }

        let whichNpm = await executeShellCommand("which npm 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichNpm.isEmpty {
            scanSteps.append((
                name: "npm",
                title: "npm 全局模块",
                scan: { [self] in
                    let npmOut = await executeShellCommand("npm list -g --depth=0 --json 2>/dev/null", streamOutput: false)
                    return PackageParsers.parseInstalledNpm(jsonString: npmOut, outdatedMap: outdatedMap)
                }
            ))
        }

        let whichMas = await executeShellCommand("which mas 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichMas.isEmpty {
            scanSteps.append((
                name: "Mac App Store",
                title: "Mac App Store 应用",
                scan: { [self] in
                    let masOut = await executeShellCommand("mas list 2>/dev/null", streamOutput: false)
                    return PackageParsers.parseInstalledMas(outputString: masOut, outdatedMap: outdatedMap)
                }
            ))
        }

        let whichVolta = await executeShellCommand("which volta 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichVolta.isEmpty {
            scanSteps.append((
                name: "Volta",
                title: "Volta 全局工具包",
                scan: { [self] in
                    let voltaOut = await executeShellCommand("volta list all 2>/dev/null", streamOutput: false)
                    return PackageParsers.parseInstalledVolta(output: voltaOut, outdatedMap: outdatedMap)
                }
            ))
        }

        let whichPipx = await executeShellCommand("which pipx 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichPipx.isEmpty {
            scanSteps.append((
                name: "pipx",
                title: "pipx (Python 工具)",
                scan: { [self] in
                    let pipxOut = await executeShellCommand("pipx list --json 2>/dev/null", streamOutput: false)
                    return PackageParsers.parseInstalledPipx(jsonString: pipxOut, outdatedMap: outdatedMap)
                }
            ))
        }

        let whichCargo = await executeShellCommand("which cargo 2>/dev/null", streamOutput: false).trimmingCharacters(in: .whitespacesAndNewlines)
        if !whichCargo.isEmpty {
            scanSteps.append((
                name: "Cargo",
                title: "Cargo (Rust 工具)",
                scan: { [self] in
                    let cargoOut = await executeShellCommand("cargo install --list 2>/dev/null", streamOutput: false)
                    return PackageParsers.parseInstalledCargo(output: cargoOut, outdatedMap: outdatedMap)
                }
            ))
        }

        let totalSteps = scanSteps.count
        onOutput("==> 开始扫描本机已安装软件与工具链 (共 \(totalSteps) 种包管理器)...")

        for (index, step) in scanSteps.enumerated() {
            let stepNum = index + 1
            onOutput("==> [\(stepNum)/\(totalSteps)] 扫描 \(step.title)...")
            let found = await step.scan()
            items.append(contentsOf: found)
            onOutput("  ✓ \(step.name) 发现 \(found.count) 个已安装项")
        }

        onOutput("--------------------------------------------------")
        onOutput("✓ 扫描完成：共检测到 \(items.count) 项已安装应用与工具")
        return items
    }

    public func cancel() {
        currentProcess?.terminate()
        currentProcess = nil
    }

    private static var standardPathPrefix: String {
        let home = NSHomeDirectory()
        return "\(home)/.local/bin:\(home)/.cargo/bin:\(home)/.volta/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin"
    }

    private func wrapCommand(_ command: String) -> String {
        let askpass = askpassURL.path
        let pathPrefix = Self.standardPathPrefix
        return """
        if [ -f "$HOME/.zshrc" ]; then
            source "$HOME/.zshrc" >/dev/null 2>&1
        fi
        export PATH="\(pathPrefix):$PATH"
        export SUDO_ASKPASS='\(askpass)'
        \(command)
        """
    }

    @discardableResult
    private func executeShellCommand(_ command: String, streamOutput: Bool) async -> String {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: "")
                    return
                }
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                var env = ProcessInfo.processInfo.environment
                env["SUDO_ASKPASS"] = self.askpassURL.path
                let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
                env["PATH"] = "\(Self.standardPathPrefix):\(currentPath)"
                proc.environment = env
                proc.arguments = ["-l", "-c", self.wrapCommand(command)]

                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe

                do {
                    try proc.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    private func executeShellCommandWithStreaming(_ command: String, onOutput: @escaping (String) -> Void) async -> Int32 {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: -1)
                    return
                }
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                var env = ProcessInfo.processInfo.environment
                env["SUDO_ASKPASS"] = self.askpassURL.path
                let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
                env["PATH"] = "\(Self.standardPathPrefix):\(currentPath)"
                proc.environment = env
                proc.arguments = ["-l", "-c", self.wrapCommand(command)]

                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                    DispatchQueue.main.async {
                        onOutput(str)
                    }
                    self.appendLog(str)
                }

                self.currentProcess = proc

                do {
                    try proc.run()
                    proc.waitUntilExit()
                    pipe.fileHandleForReading.readabilityHandler = nil
                    let code = proc.terminationStatus
                    self.currentProcess = nil
                    continuation.resume(returning: code)
                } catch {
                    self.currentProcess = nil
                    continuation.resume(returning: -1)
                }
            }
        }
    }

    private func appendLog(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: logFileURL)
        }
    }
}
