import XCTest
@testable import MacDeck

final class CoordinateConversionTests: XCTestCase {
    func testRelativeCalculationWithinScreen() {
        let screenOrigin = CGPoint(x: 1000, y: 500)
        let windowFrame = CGRect(x: 1200, y: 600, width: 800, height: 600)

        let relX = windowFrame.origin.x - screenOrigin.x
        let relY = windowFrame.origin.y - screenOrigin.y

        XCTAssertEqual(relX, 200)
        XCTAssertEqual(relY, 100)
    }

    func testSafeClamping() {
        let display = DisplayInfo(id: 1, name: "Screen", isMain: true, boundsWidth: 1920, boundsHeight: 1080, originX: 0, originY: 0)
        let targetRect = DisplayManager.clampToScreen(rect: CGRect(x: 2000, y: 1500, width: 1000, height: 800), screen: display)

        XCTAssertLessThanOrEqual(targetRect.maxX, 1920)
        XCTAssertLessThanOrEqual(targetRect.maxY, 1080)
        XCTAssertEqual(targetRect.width, 1000)
        XCTAssertEqual(targetRect.height, 800)
    }

    func testNegativeCoordinatesClamping() {
        let display = DisplayInfo(id: 2, name: "LeftScreen", isMain: false, boundsWidth: 2160, boundsHeight: 3840, originX: -2160, originY: -1431)
        let targetRect = DisplayManager.clampToScreen(rect: CGRect(x: -3000, y: -2000, width: 1000, height: 800), screen: display)

        XCTAssertGreaterThanOrEqual(targetRect.origin.x, -2160)
        XCTAssertGreaterThanOrEqual(targetRect.origin.y, -1431)
        XCTAssertLessThanOrEqual(targetRect.maxX, 0)
    }
}
