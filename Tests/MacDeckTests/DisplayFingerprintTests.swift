import XCTest
@testable import MacDeck

final class DisplayFingerprintTests: XCTestCase {
    func testFingerprintIsOrderIndependent() {
        let d1 = DisplayInfo(id: 1, uuid: "UUID-A", name: "Screen A", isMain: true, boundsWidth: 1920, boundsHeight: 1080, originX: 0, originY: 0)
        let d2 = DisplayInfo(id: 2, uuid: "UUID-B", name: "Screen B", isMain: false, boundsWidth: 3840, boundsHeight: 2160, originX: 1920, originY: 0)

        let fp1 = DisplayManager.computeTopologyFingerprint(displays: [d1, d2])
        let fp2 = DisplayManager.computeTopologyFingerprint(displays: [d2, d1])

        XCTAssertEqual(fp1, fp2, "Fingerprint should be identical regardless of screen enumeration order")
    }

    func testFingerprintChangesWhenResolutionChanges() {
        let d1 = DisplayInfo(id: 1, uuid: "UUID-A", name: "Screen A", isMain: true, boundsWidth: 1920, boundsHeight: 1080, originX: 0, originY: 0)
        let d1Changed = DisplayInfo(id: 1, uuid: "UUID-A", name: "Screen A", isMain: true, boundsWidth: 2560, boundsHeight: 1440, originX: 0, originY: 0)

        let fp1 = DisplayManager.computeTopologyFingerprint(displays: [d1])
        let fp2 = DisplayManager.computeTopologyFingerprint(displays: [d1Changed])

        XCTAssertNotEqual(fp1, fp2)
    }

    func testFingerprintChangesWhenScreenCountChanges() {
        let d1 = DisplayInfo(id: 1, uuid: "UUID-A", name: "Screen A", isMain: true, boundsWidth: 1920, boundsHeight: 1080, originX: 0, originY: 0)
        let d2 = DisplayInfo(id: 2, uuid: "UUID-B", name: "Screen B", isMain: false, boundsWidth: 3840, boundsHeight: 2160, originX: 1920, originY: 0)

        let fpSingle = DisplayManager.computeTopologyFingerprint(displays: [d1])
        let fpDual = DisplayManager.computeTopologyFingerprint(displays: [d1, d2])

        XCTAssertNotEqual(fpSingle, fpDual)
    }
}
