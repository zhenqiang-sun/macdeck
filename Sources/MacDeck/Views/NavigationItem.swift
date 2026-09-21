import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case systemInfo = "systemInfo"
    case windowLayout = "windowLayout"
    case displays = "displays"
    case softwareUpdate = "softwareUpdate"
    case environment = "environment"
    case settings = "settings"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemInfo:
            return "nav.system_info".localized
        case .windowLayout:
            return "nav.window_layout".localized
        case .displays:
            return "nav.displays".localized
        case .softwareUpdate:
            return "nav.software_update".localized
        case .environment:
            return "nav.environment".localized
        case .settings:
            return "nav.settings".localized
        }
    }

    var icon: String {
        switch self {
        case .systemInfo:
            return "laptopcomputer"
        case .windowLayout:
            return "macwindow.on.rectangle"
        case .displays:
            return "display.2"
        case .softwareUpdate:
            return "arrow.triangle.2.circlepath.circle"
        case .environment:
            return "wrench.and.screwdriver"
        case .settings:
            return "gearshape"
        }
    }
}
