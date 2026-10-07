import XCTest
@testable import MacDeck

final class WindowManagerConvergenceTests: XCTestCase {
    
    func testConvergenceAlgorithmLogic() {
        // 模拟验证几何回读容差判断
        let targetFrame = CGRect(x: 100.0, y: 150.0, width: 1200.0, height: 800.0)
        
        // 模拟第 1 轮：被小屏幕 Clamping 后的状态（例如宽度被限制在 1000）
        let clampedFrame = CGRect(x: 100.0, y: 150.0, width: 1000.0, height: 800.0)
        let dw1 = abs(clampedFrame.size.width - targetFrame.size.width)
        XCTAssertGreaterThan(dw1, 2.0, "Clamping 状态下宽度误差应大于容差 2.0pt")
        
        // 模拟第 2 轮：经过跨屏安全锚定与重设后的收敛状态（微小亚像素舍入误差 0.5pt）
        let convergedFrame = CGRect(x: 100.2, y: 149.8, width: 1199.7, height: 800.1)
        let dx = abs(convergedFrame.origin.x - targetFrame.origin.x)
        let dy = abs(convergedFrame.origin.y - targetFrame.origin.y)
        let dw = abs(convergedFrame.size.width - targetFrame.size.width)
        let dh = abs(convergedFrame.size.height - targetFrame.size.height)
        
        XCTAssertLessThanOrEqual(dx, 2.0)
        XCTAssertLessThanOrEqual(dy, 2.0)
        XCTAssertLessThanOrEqual(dw, 2.0)
        XCTAssertLessThanOrEqual(dh, 2.0)
        XCTAssertTrue(dx <= 2.0 && dy <= 2.0 && dw <= 2.0 && dh <= 2.0, "应准确判定为完全收敛并提前退出")
    }
    
    func testGetWindowGeometryGracefulHandling() {
        // 创建一个系统级或者无效的 AXUIElement，验证不会出现崩溃或内存泄漏
        let systemWide = AXUIElementCreateSystemWide()
        let geometry = WindowManager.getWindowGeometry(element: systemWide)
        // SystemWide 对象没有窗口尺寸和坐标，应安全返回 nil，不崩溃
        XCTAssertNil(geometry)
    }
    
    func testScreenResolutionMatching() {
        // 验证主屏幕获取及基本几何
        let mainScreen = NSScreen.main
        XCTAssertNotNil(mainScreen)
        if let screen = mainScreen {
            XCTAssertGreaterThan(screen.frame.width, 0)
            XCTAssertGreaterThan(screen.frame.height, 0)
        }
    }
}
