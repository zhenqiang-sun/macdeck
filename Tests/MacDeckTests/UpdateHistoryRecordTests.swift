import XCTest
@testable import MacDeck

final class UpdateHistoryRecordTests: XCTestCase {
    func testUpdateHistoryRecordSerialization() throws {
        let record = UpdateHistoryRecord(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            timestamp: Date(timeIntervalSince1970: 1700000000),
            packageId: "git",
            packageName: "git",
            source: .brewFormula,
            previousVersion: "2.40.0",
            targetVersion: "2.41.0",
            status: .success,
            command: "brew upgrade git",
            outputLog: "==> Upgrading git\nSuccess",
            rollbackHint: "brew install git@2.40.0"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UpdateHistoryRecord.self, from: data)

        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.packageId, "git")
        XCTAssertEqual(decoded.source, .brewFormula)
        XCTAssertEqual(decoded.previousVersion, "2.40.0")
        XCTAssertEqual(decoded.targetVersion, "2.41.0")
        XCTAssertEqual(decoded.status, .success)
        XCTAssertEqual(decoded.rollbackHint, "brew install git@2.40.0")
    }

    func testRollbackHelper() {
        XCTAssertEqual(
            RollbackHelper.generateHint(source: .brewFormula, name: "node", previousVersion: "18.0.0"),
            "brew install node@18.0.0"
        )
        XCTAssertEqual(
            RollbackHelper.generateHint(source: .npmGlobal, name: "typescript", previousVersion: "5.0.0"),
            "npm install -g typescript@5.0.0"
        )
        XCTAssertEqual(
            RollbackHelper.generateHint(source: .pipx, name: "black", previousVersion: "23.1.0"),
            "pipx install black==23.1.0 --force"
        )
        XCTAssertEqual(
            RollbackHelper.generateHint(source: .volta, name: "node", previousVersion: "18.16.0"),
            "volta install node@18.16.0"
        )
        XCTAssertEqual(
            RollbackHelper.generateHint(source: .cargo, name: "ripgrep", previousVersion: "13.0.0"),
            "cargo install ripgrep --version 13.0.0 --force"
        )
        XCTAssertNil(
            RollbackHelper.generateHint(source: .brewFormula, name: "node", previousVersion: "")
        )
        XCTAssertNil(
            RollbackHelper.generateHint(source: .appStore, name: "Xcode", previousVersion: "14.0")
        )
    }
}
