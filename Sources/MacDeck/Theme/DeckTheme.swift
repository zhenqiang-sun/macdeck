import SwiftUI
import AppKit

/// MacDeck 全局设计系统与视觉规范 Tokens
/// 严格对齐 Apple Human Interface Guidelines (HIG) 与现代 macOS 精致设计语言
enum DeckTheme {

    // MARK: - 控件高度规范 (Control Heights)
    enum ControlHeight {
        /// 主操作按钮标准高度 (30pt，符合 macOS 现代视窗中强调色按钮黄金比例)
        static let regular: CGFloat = 30
        /// 列表行内操作与辅助紧凑按钮高度 (24pt)
        static let compact: CGFloat = 24
        /// 正方形工具图标按钮尺寸 (30x30pt)
        static let iconRegular: CGFloat = 30
        /// 紧凑型图标按钮尺寸 (24x24pt)
        static let iconCompact: CGFloat = 24
        /// 微型状态或步进图标尺寸 (18x18pt)
        static let iconMini: CGFloat = 18
    }

    // MARK: - 同心圆角规范 (Nested Corner Radii)
    // 遵循 R_inner = R_outer - Padding 原则，杜绝圆角挤压
    enum CornerRadius {
        /// 外层主卡片/容器外框圆角 (10pt)
        static let outer: CGFloat = 10
        /// 卡片内层项/二级容器圆角 (8pt)
        static let card: CGFloat = 8
        /// 标准按钮圆角 (7pt)
        static let button: CGFloat = 7
        /// 紧凑按钮与筛选滑块圆角 (5~6pt)
        static let compact: CGFloat = 5
        /// 状态角标与小标签圆角 (4pt)
        static let badge: CGFloat = 4
    }

    // MARK: - 间距规范 (Spacing)
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    // MARK: - 语义化色彩与材质 (Semantic Colors & Materials)
    enum Colors {
        /// 品牌主强调色
        static var accent: Color { Color.accentColor }

        /// 品牌强调色淡背景 (用于选中态、轻量徽标背景)
        static var accentMuted: Color { Color.accentColor.opacity(0.12) }

        /// 精调护眼成功色 (避免系统纯绿的高饱和刺眼感)
        static let success = Color(red: 0.20, green: 0.65, blue: 0.40)

        /// 精调琥珀警示色
        static let warning = Color(red: 0.90, green: 0.55, blue: 0.18)

        /// 精调破坏性警示红
        static let danger = Color(red: 0.85, green: 0.28, blue: 0.28)

        /// 精调典雅紫 (用于 Profile/Tag)
        static let purple = Color(red: 0.56, green: 0.36, blue: 0.86)

        /// 精调科技蓝
        static let infoBlue = Color(red: 0.22, green: 0.52, blue: 0.88)

        // MARK: - 背景与描边透明度梯度
        /// 凹槽底板背景色 (用于 Segmented 选择器、搜索框等底板)
        static var trackBackground: Color { Color.secondary.opacity(0.08) }

        /// 次级/次要按钮背景浅填充
        static var secondaryFill: Color { Color.secondary.opacity(0.12) }

        /// 悬停微高亮填充
        static var hoverFill: Color { Color.secondary.opacity(0.16) }

        /// 极细分隔线与微弱外描边
        static var subtleBorder: Color { Color.primary.opacity(0.06) }

        /// 稍明显的控制项边框
        static var controlBorder: Color { Color.primary.opacity(0.10) }

        /// 卡片与输入框边框
        static var cardBorder: Color { Color.primary.opacity(0.10) }

        /// 卡片背景 (系统 controlBackgroundColor)
        static var cardBackground: Color { Color(NSColor.controlBackgroundColor) }
    }
}
