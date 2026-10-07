import XCTest
@testable import MacDeck

final class LocalizationAuditTests: XCTestCase {

    private func getLocalesDirectory() -> URL {
        let currentFile = URL(fileURLWithPath: #filePath)
        let root = currentFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return root.appendingPathComponent("Sources/MacDeck/Resources/Locales")
    }

    private func loadFlatKeys(from fileURL: URL) throws -> [String: String] {
        let data = try Data(contentsOf: fileURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse JSON at \(fileURL.path)")
            return [:]
        }
        return flatten(dictionary: json)
    }

    private func flatten(dictionary: [String: Any], prefix: String = "") -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            let combinedKey = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let nested = value as? [String: Any] {
                let subResult = flatten(dictionary: nested, prefix: combinedKey)
                for (k, v) in subResult {
                    result[k] = v
                }
            } else if let str = value as? String {
                result[combinedKey] = str
            }
        }
        return result
    }

    func testAllLanguagePacksHaveIdenticalKeys() throws {
        let localesDir = getLocalesDirectory()
        let languages = ["en", "zh-Hans", "zh-Hant", "ja"]
        var packs: [String: [String: String]] = [:]

        for lang in languages {
            let fileURL = localesDir.appendingPathComponent("\(lang).json")
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Locale file missing: \(fileURL.path)")
            packs[lang] = try loadFlatKeys(from: fileURL)
        }

        guard let enKeys = packs["en"]?.keys else {
            XCTFail("English pack is empty")
            return
        }

        let enKeySet = Set(enKeys)

        for lang in ["zh-Hans", "zh-Hant", "ja"] {
            guard let langPack = packs[lang] else { continue }
            let langKeySet = Set(langPack.keys)

            let missing = enKeySet.subtracting(langKeySet)
            let extra = langKeySet.subtracting(enKeySet)

            XCTAssertTrue(missing.isEmpty, "[\(lang)] is missing keys found in [en]: \(missing)")
            XCTAssertTrue(extra.isEmpty, "[\(lang)] has extra keys not in [en]: \(extra)")
        }
    }

    func testAllKeysUsedInCodeExistInLocalePacks() throws {
        let localesDir = getLocalesDirectory()
        let enPack = try loadFlatKeys(from: localesDir.appendingPathComponent("en.json"))
        let enKeySet = Set(enPack.keys)

        let rootDir = localesDir.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sourcesDir = rootDir.appendingPathComponent("Sources/MacDeck")

        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)

        let localizedRegex = try NSRegularExpression(pattern: "\"([a-zA-Z0-9_\\.\\-]+)\"\\.localized")
        let l10nRegex = try NSRegularExpression(pattern: "L10n\\.t\\(\"([a-zA-Z0-9_\\.\\-]+)\"\\)")

        var missingKeys: [(file: String, key: String)] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let nsContent = content as NSString

            let localizedMatches = localizedRegex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
            for match in localizedMatches {
                let key = nsContent.substring(with: match.range(at: 1))
                if !enKeySet.contains(key) {
                    missingKeys.append((fileURL.lastPathComponent, key))
                }
            }

            let l10nMatches = l10nRegex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
            for match in l10nMatches {
                let key = nsContent.substring(with: match.range(at: 1))
                if !enKeySet.contains(key) {
                    missingKeys.append((fileURL.lastPathComponent, key))
                }
            }
        }

        XCTAssertTrue(missingKeys.isEmpty, "Found keys in Swift code that are missing from locales: \(missingKeys)")
    }
}
