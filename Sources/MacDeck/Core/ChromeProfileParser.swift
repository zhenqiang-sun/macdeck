import Foundation

public enum ChromeProfileParser {
    private static let multiProfileRegex = try! NSRegularExpression(pattern: #"^(.*?)\s*-\s*Google Chrome\s*-\s*(.+)$"#)
    private static let standardChromeRegex = try! NSRegularExpression(pattern: #"^(.*?)\s*-\s*Google Chrome$"#)

    public static func parse(windowTitle: String) -> (pageTitle: String, profile: String?) {
        let fullRange = NSRange(windowTitle.startIndex..<windowTitle.endIndex, in: windowTitle)

        if let match = multiProfileRegex.firstMatch(in: windowTitle, range: fullRange) {
            let pageRange = Range(match.range(at: 1), in: windowTitle)!
            let profileRange = Range(match.range(at: 2), in: windowTitle)!
            return (String(windowTitle[pageRange]), String(windowTitle[profileRange]))
        }

        if let match = standardChromeRegex.firstMatch(in: windowTitle, range: fullRange) {
            let pageRange = Range(match.range(at: 1), in: windowTitle)!
            return (String(windowTitle[pageRange]), nil)
        }

        return (windowTitle, nil)
    }
}
