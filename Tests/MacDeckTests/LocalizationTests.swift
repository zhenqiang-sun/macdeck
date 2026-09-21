import XCTest
@testable import MacDeck

final class LocalizationTests: XCTestCase {
    func testLanguageResolution() {
        XCTAssertEqual(LocalizationService.resolveEffectiveLanguage(from: .en), .en)
        XCTAssertEqual(LocalizationService.resolveEffectiveLanguage(from: .zhHans), .zhHans)
        
        let systemEffective = LocalizationService.resolveEffectiveLanguage(from: .system)
        XCTAssertTrue(systemEffective == .en || systemEffective == .zhHans)
    }

    func testDictionaryKeysAreConsistent() {
        let loc = LocalizationService.shared
        
        // 切换为英文测试
        loc.setLanguage(.en)
        let enDisplays = L10n.t("nav.displays")
        XCTAssertEqual(enDisplays, "Displays & Presets")
        
        let enUptime = L10n.t("sysinfo.uptime")
        XCTAssertEqual(enUptime, "System Uptime")
        
        // 切换为中文测试
        loc.setLanguage(.zhHans)
        let zhDisplays = L10n.t("nav.displays")
        XCTAssertEqual(zhDisplays, "多屏拓扑")
        
        let zhUptime = L10n.t("sysinfo.uptime")
        XCTAssertEqual(zhUptime, "系统运行时间")
    }

    func testFormattedStringInterpolation() {
        let loc = LocalizationService.shared
        
        loc.setLanguage(.en)
        let enCount = L10n.t("displays.displays_count", 3)
        XCTAssertEqual(enCount, "3 Displays")
        
        loc.setLanguage(.zhHans)
        let zhCount = L10n.t("displays.displays_count", 3)
        XCTAssertEqual(zhCount, "3 台显示器")
    }

    func testStringExtension() {
        let loc = LocalizationService.shared
        loc.setLanguage(.en)
        XCTAssertEqual("common.refresh".localized, "Refresh")
        
        loc.setLanguage(.zhHans)
        XCTAssertEqual("common.refresh".localized, "刷新")
    }

    func testAllLanguagePacksHaveIdenticalKeys() throws {
        func loadKeys(code: String) throws -> Set<String> {
            let fileURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // MacDeckTests
                .deletingLastPathComponent() // Tests
                .deletingLastPathComponent() // root
                .appendingPathComponent("Resources/Locales/\(code).json")
            
            let data = try Data(contentsOf: fileURL)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            
            func flattenKeys(dict: [String: Any], prefix: String = "") -> Set<String> {
                var keys = Set<String>()
                for (k, v) in dict {
                    let fullKey = prefix.isEmpty ? k : "\(prefix).\(k)"
                    if let nested = v as? [String: Any] {
                        keys.formUnion(flattenKeys(dict: nested, prefix: fullKey))
                    } else {
                        keys.insert(fullKey)
                    }
                }
                return keys
            }
            
            return flattenKeys(dict: json)
        }

        let enKeys = try loadKeys(code: "en")
        let zhKeys = try loadKeys(code: "zh-Hans")

        let missingInZh = enKeys.subtracting(zhKeys)
        let missingInEn = zhKeys.subtracting(enKeys)

        XCTAssertTrue(missingInZh.isEmpty, "Keys missing in zh-Hans.json: \(missingInZh)")
        XCTAssertTrue(missingInEn.isEmpty, "Keys missing in en.json: \(missingInEn)")
        XCTAssertEqual(enKeys, zhKeys, "Localization keys must match 1:1 between languages")
    }
}
