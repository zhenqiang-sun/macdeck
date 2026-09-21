import Foundation

public struct PackageParsers {
    private struct BrewOutdatedPayload: Decodable {
        struct Entry: Decodable {
            let name: String
            let installed_versions: [String]
            let current_version: String
        }
        let formulae: [Entry]
        let casks: [Entry]
    }

    private struct NpmEntry: Decodable {
        let current: String?
        let latest: String?
    }

    public static func parseBrewOutdated(jsonString: String) -> [SoftwarePackageItem] {
        guard let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(BrewOutdatedPayload.self, from: data) else {
            return []
        }

        var results: [SoftwarePackageItem] = []

        for item in payload.casks {
            let current = item.installed_versions.first ?? "未知"
            let formattedName = formatCaskName(item.name)
            results.append(SoftwarePackageItem(
                id: "brew:cask:\(item.name)",
                rawName: item.name,
                displayName: formattedName,
                currentVersion: current,
                latestVersion: item.current_version,
                source: .brewCask
            ))
        }

        for item in payload.formulae {
            let current = item.installed_versions.first ?? "未知"
            results.append(SoftwarePackageItem(
                id: "brew:formula:\(item.name)",
                rawName: item.name,
                displayName: item.name,
                currentVersion: current,
                latestVersion: item.current_version,
                source: .brewFormula
            ))
        }

        return results
    }

    public static func parseNpmOutdated(jsonString: String) -> [SoftwarePackageItem] {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: NpmEntry].self, from: data) else {
            return []
        }

        var results: [SoftwarePackageItem] = []
        for (pkgName, entry) in dict {
            guard let latest = entry.latest, let current = entry.current else { continue }
            results.append(SoftwarePackageItem(
                id: "npm:global:\(pkgName)",
                rawName: pkgName,
                displayName: pkgName,
                currentVersion: current,
                latestVersion: latest,
                source: .npmGlobal
            ))
        }
        return results.sorted { $0.rawName < $1.rawName }
    }

    public static func parseMasOutdated(outputString: String) -> [SoftwarePackageItem] {
        var results: [SoftwarePackageItem] = []
        let lines = outputString.components(separatedBy: .newlines)
        // Format: 497799835 Xcode (15.2 -> 15.3)
        let pattern = #"^(\d+)\s+(.+?)\s+\((.+?)\s*->\s*(.+?)\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                if match.numberOfRanges == 5,
                   let idRange = Range(match.range(at: 1), in: trimmed),
                   let nameRange = Range(match.range(at: 2), in: trimmed),
                   let curRange = Range(match.range(at: 3), in: trimmed),
                   let latRange = Range(match.range(at: 4), in: trimmed) {
                    let id = String(trimmed[idRange])
                    let name = String(trimmed[nameRange])
                    let current = String(trimmed[curRange])
                    let latest = String(trimmed[latRange])
                    results.append(SoftwarePackageItem(
                        id: "mas:\(id)",
                        rawName: id,
                        displayName: name,
                        currentVersion: current,
                        latestVersion: latest,
                        source: .appStore
                    ))
                }
            }
        }
        return results
    }

    public static func parseInstalledBrew(casksOutput: String, formulaeOutput: String, outdatedMap: [String: String] = [:]) -> [SoftwarePackageItem] {
        var results: [SoftwarePackageItem] = []

        let caskLines = casksOutput.components(separatedBy: .newlines)
        for line in caskLines {
            let name = line.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !name.contains("Error:"), !name.contains("Run `brew") else { continue }
            let latest = outdatedMap[name] ?? "最新"
            results.append(SoftwarePackageItem(
                id: "brew:cask:\(name)",
                rawName: name,
                displayName: formatCaskName(name),
                currentVersion: latest != "最新" ? "有更新" : "已安装",
                latestVersion: latest,
                source: .brewCask,
                isSelected: false
            ))
        }

        let formulaLines = formulaeOutput.components(separatedBy: .newlines)
        for line in formulaLines {
            let name = line.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !name.contains("Error:"), !name.contains("Run `brew") else { continue }
            let latest = outdatedMap[name] ?? "最新"
            results.append(SoftwarePackageItem(
                id: "brew:formula:\(name)",
                rawName: name,
                displayName: name,
                currentVersion: latest != "最新" ? "有更新" : "已安装",
                latestVersion: latest,
                source: .brewFormula,
                isSelected: false
            ))
        }

        return results.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    private struct NpmListPayload: Decodable {
        struct Dep: Decodable {
            let version: String?
        }
        let dependencies: [String: Dep]?
    }

    public static func parseInstalledNpm(jsonString: String, outdatedMap: [String: String] = [:]) -> [SoftwarePackageItem] {
        guard let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(NpmListPayload.self, from: data),
              let deps = payload.dependencies else {
            return []
        }

        var results: [SoftwarePackageItem] = []
        for (pkgName, dep) in deps {
            let current = dep.version ?? "未知"
            let latest = outdatedMap[pkgName] ?? current
            results.append(SoftwarePackageItem(
                id: "npm:global:\(pkgName)",
                rawName: pkgName,
                displayName: pkgName,
                currentVersion: current,
                latestVersion: latest,
                source: .npmGlobal,
                isSelected: false
            ))
        }
        return results.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    public static func parseInstalledMas(outputString: String, outdatedMap: [String: String] = [:]) -> [SoftwarePackageItem] {
        var results: [SoftwarePackageItem] = []
        let lines = outputString.components(separatedBy: .newlines)
        // Format: 497799835 Xcode (15.2)
        let pattern = #"^\s*(\d+)\s+(.+?)\s+\((.+?)\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                if match.numberOfRanges == 4,
                   let idRange = Range(match.range(at: 1), in: trimmed),
                   let nameRange = Range(match.range(at: 2), in: trimmed),
                   let curRange = Range(match.range(at: 3), in: trimmed) {
                    let id = String(trimmed[idRange])
                    let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
                    let current = String(trimmed[curRange])
                    let latest = outdatedMap[id] ?? current
                    results.append(SoftwarePackageItem(
                        id: "mas:\(id)",
                        rawName: id,
                        displayName: name,
                        currentVersion: current,
                        latestVersion: latest,
                        source: .appStore,
                        isSelected: false
                    ))
                }
            }
        }
        return results.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    public static func parseInstalledVolta(output: String, outdatedMap: [String: String] = [:]) -> [SoftwarePackageItem] {
        var results: [SoftwarePackageItem] = []
        let lines = output.components(separatedBy: .newlines)

        var inPackagesSection = false
        // Matches e.g. "        @teable/cli@0.6.29 (default)" or "    pnpm@11.23.0"
        let packagePattern = #"^\s+(@?[^@\s:]+)@([^@\s:]+?)(?:\s+\(.*?\))?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: packagePattern) else { return [] }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "Packages:" {
                inPackagesSection = true
                continue
            }

            // If we hit another section header like "Node runtimes:" (less than 8 spaces indentation), exit packages section
            if inPackagesSection && !line.hasPrefix("        ") && trimmed.hasSuffix(":") {
                inPackagesSection = false
                continue
            }

            if inPackagesSection {
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    if match.numberOfRanges >= 3,
                       let nameRange = Range(match.range(at: 1), in: line),
                       let verRange = Range(match.range(at: 2), in: line) {
                        let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
                        let currentVersion = String(line[verRange]).trimmingCharacters(in: .whitespaces)
                        let latest = outdatedMap[name] ?? "最新"

                        results.append(SoftwarePackageItem(
                            id: "volta:\(name)",
                            rawName: name,
                            displayName: name,
                            currentVersion: currentVersion,
                            latestVersion: latest,
                            source: .volta,
                            isSelected: false
                        ))
                    }
                }
            }
        }

        return results.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    private static func formatCaskName(_ raw: String) -> String {
        return raw.split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    // MARK: - Pipx
    private struct PipxListPayload: Decodable {
        struct Venv: Decodable {
            struct Metadata: Decodable {
                struct MainPackage: Decodable {
                    let package: String
                    let package_version: String
                }
                let main_package: MainPackage?
            }
            let metadata: Metadata?
        }
        let venvs: [String: Venv]?
    }

    public static func parseInstalledPipx(jsonString: String, outdatedMap: [String: String] = [:]) -> [SoftwarePackageItem] {
        guard let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PipxListPayload.self, from: data),
              let venvs = payload.venvs else {
            return []
        }

        var results: [SoftwarePackageItem] = []
        for (_, venv) in venvs {
            guard let main = venv.metadata?.main_package else { continue }
            let name = main.package
            let current = main.package_version
            let latest = outdatedMap[name] ?? "最新"
            results.append(SoftwarePackageItem(
                id: "pipx:\(name)",
                rawName: name,
                displayName: name,
                currentVersion: current,
                latestVersion: latest,
                source: .pipx,
                isSelected: false
            ))
        }
        return results.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    // MARK: - Cargo
    public static func parseInstalledCargo(output: String, outdatedMap: [String: String] = [:]) -> [SoftwarePackageItem] {
        var results: [SoftwarePackageItem] = []
        let lines = output.components(separatedBy: .newlines)
        // Format: cargo-update v22.1.1:
        let pattern = #"^([a-zA-Z0-9_-]+)\s+v([^\s:]+):"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                if match.numberOfRanges >= 3,
                   let nameRange = Range(match.range(at: 1), in: trimmed),
                   let verRange = Range(match.range(at: 2), in: trimmed) {
                    let name = String(trimmed[nameRange])
                    let current = String(trimmed[verRange])
                    let latest = outdatedMap[name] ?? "最新"
                    results.append(SoftwarePackageItem(
                        id: "cargo:\(name)",
                        rawName: name,
                        displayName: name,
                        currentVersion: current,
                        latestVersion: latest,
                        source: .cargo,
                        isSelected: false
                    ))
                }
            }
        }
        return results.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    public static func parseCargoInstallUpdateList(output: String) -> [SoftwarePackageItem] {
        var results: [SoftwarePackageItem] = []
        let lines = output.components(separatedBy: .newlines)
        // Format: Package       Installed  Latest   Needs update
        // e.g.:   ripgrep       v13.0.0    v14.1.0  Yes
        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 4 else { continue }
            let name = parts[0]
            if name == "Package" || name.contains("Polling") { continue }
            let installed = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let latest = parts[2].trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let needsUpdate = parts[3].lowercased() == "yes" || (parts.count >= 5 && parts[parts.count - 1].lowercased() == "yes")
            if needsUpdate {
                results.append(SoftwarePackageItem(
                    id: "cargo:\(name)",
                    rawName: name,
                    displayName: name,
                    currentVersion: installed,
                    latestVersion: latest,
                    source: .cargo,
                    isSelected: false
                ))
            }
        }
        return results.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }
}
