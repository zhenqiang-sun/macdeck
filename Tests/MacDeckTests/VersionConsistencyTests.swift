import XCTest
@testable import MacDeck

final class VersionConsistencyTests: XCTestCase {
    func testSingleSourceOfTruthVersionMatchesCask() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MacDeckTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Root
        
        let versionFileURL = rootURL.appendingPathComponent("VERSION")
        let versionString = try String(contentsOf: versionFileURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 验证语义化版本格式 (e.g. 1.2.0)
        let semverRegex = "^\\d+\\.\\d+\\.\\d+$"
        XCTAssertNotNil(versionString.range(of: semverRegex, options: .regularExpression), "VERSION must follow semantic versioning X.Y.Z, got: \(versionString)")
        
        // 验证 Casks/macdeck.rb 包含该版本
        let caskURL = rootURL.appendingPathComponent("Casks/macdeck.rb")
        let caskContent = try String(contentsOf: caskURL, encoding: .utf8)
        XCTAssertTrue(caskContent.contains("version \"\(versionString)\""), "Casks/macdeck.rb version must match VERSION file (\(versionString))")
    }

    func testNoHardcodedVersionBadgeInViews() throws {
        let sourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MacDeck/Views")
        
        let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: nil)
        var hardcodedMatches: [String] = []
        
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            
            // 匹配 Text("v1.X.X") 等硬编码模式
            let regex = try NSRegularExpression(pattern: #"Text\(\s*"v\d+\.\d+[^"]*"\)"#, options: [])
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            if !matches.isEmpty {
                hardcodedMatches.append(fileURL.lastPathComponent)
            }
        }
        
        XCTAssertTrue(hardcodedMatches.isEmpty, "Found hardcoded version strings in views: \(hardcodedMatches). Use dynamic Bundle version instead!")
    }
}
