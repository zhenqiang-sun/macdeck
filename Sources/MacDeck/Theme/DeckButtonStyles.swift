import SwiftUI
import AppKit

// MARK: - 主操作按钮样式 (DeckPrimaryButtonStyle)
/// 用于视图中最关键的首要动作 (如“一键归位”、“升级所选项”)
struct DeckPrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = DeckTheme.ControlHeight.regular
    var cornerRadius: CGFloat = DeckTheme.CornerRadius.button
    var customColor: Color? = nil

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let bgColor = customColor ?? DeckTheme.Colors.accent

        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(bgColor.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.4))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 次要操作按钮样式 (DeckSecondaryButtonStyle)
/// 用于并排的重要次级操作 (如“快照当前”、“重新扫描”、“检查更新”)
struct DeckSecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = DeckTheme.ControlHeight.regular
    var cornerRadius: CGFloat = DeckTheme.CornerRadius.button
    var isDestructive: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let baseColor: Color = isDestructive ? DeckTheme.Colors.danger : .primary

        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(baseColor.opacity(isEnabled ? (configuration.isPressed ? 0.6 : 0.85) : 0.35))
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        isDestructive
                            ? DeckTheme.Colors.danger.opacity(configuration.isPressed ? 0.18 : 0.08)
                            : (configuration.isPressed ? DeckTheme.Colors.hoverFill : DeckTheme.Colors.secondaryFill)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isDestructive
                            ? DeckTheme.Colors.danger.opacity(0.2)
                            : DeckTheme.Colors.subtleBorder,
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 紧凑行内操作按钮样式 (DeckCompactButtonStyle)
/// 用于列表项内、高密度表格中的操作 (如“记录当前”、“归位”、“更新”)
struct DeckCompactButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    var customColor: Color? = nil

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let accentColor = customColor ?? DeckTheme.Colors.accent

        configuration.label
            .font(.system(size: 11, weight: isProminent ? .semibold : .medium))
            .foregroundColor(
                isProminent
                    ? .white
                    : .primary.opacity(isEnabled ? (configuration.isPressed ? 0.6 : 0.85) : 0.35)
            )
            .padding(.horizontal, 8)
            .frame(height: DeckTheme.ControlHeight.compact)
            .background(
                RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.compact)
                    .fill(
                        isProminent
                            ? accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.4)
                            : (configuration.isPressed ? DeckTheme.Colors.hoverFill : DeckTheme.Colors.secondaryFill)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.compact)
                    .stroke(
                        isProminent ? Color.clear : DeckTheme.Colors.subtleBorder,
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 方形/图标工具按钮样式 (DeckIconButtonStyle)
/// 用于标题栏或工具栏上的图标按钮 (如刷新、日志、清理、更多操作)
struct DeckIconButtonStyle: ButtonStyle {
    var size: CGFloat = DeckTheme.ControlHeight.iconRegular
    var cornerRadius: CGFloat = DeckTheme.CornerRadius.button
    var isDestructive: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let iconColor: Color = isDestructive ? DeckTheme.Colors.danger : .secondary

        configuration.label
            .font(.system(size: size <= 24 ? 10 : 12, weight: .medium))
            .foregroundColor(iconColor.opacity(isEnabled ? (configuration.isPressed ? 0.5 : 0.85) : 0.3))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        configuration.isPressed
                            ? DeckTheme.Colors.hoverFill
                            : DeckTheme.Colors.secondaryFill.opacity(0.8)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isDestructive ? DeckTheme.Colors.danger.opacity(0.2) : DeckTheme.Colors.subtleBorder,
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 凹槽底板分段选择器容器 (DeckSegmentedContainer)
/// 提供现代 macOS 标准凹槽底板外观 (外层 8pt 圆角，3pt 内边距)
struct DeckSegmentedContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 2) {
            content()
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.card)
                .fill(DeckTheme.Colors.trackBackground)
        )
    }
}

// MARK: - 分段选择器选项胶囊按钮 (DeckSegmentedItem)
struct DeckSegmentedItem: View {
    let title: String
    var icon: String? = nil
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                }
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))

                if let count = count {
                    Text("(\(count))")
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                        .opacity(0.75)
                }
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.compact)
                    .fill(isSelected ? DeckTheme.Colors.cardBackground : Color.clear)
                    .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 1.5, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 统一输入框样式 (DeckTextFieldStyle)
struct DeckTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DeckTheme.Colors.cardBackground)
            .cornerRadius(DeckTheme.CornerRadius.button)
            .overlay(
                RoundedRectangle(cornerRadius: DeckTheme.CornerRadius.button)
                    .stroke(DeckTheme.Colors.controlBorder, lineWidth: 1)
            )
    }
}

// MARK: - 快捷 View 扩展
extension View {
    func deckPrimaryButton(height: CGFloat = DeckTheme.ControlHeight.regular, cornerRadius: CGFloat = DeckTheme.CornerRadius.button, color: Color? = nil) -> some View {
        self.buttonStyle(DeckPrimaryButtonStyle(height: height, cornerRadius: cornerRadius, customColor: color))
    }

    func deckSecondaryButton(height: CGFloat = DeckTheme.ControlHeight.regular, cornerRadius: CGFloat = DeckTheme.CornerRadius.button, isDestructive: Bool = false) -> some View {
        self.buttonStyle(DeckSecondaryButtonStyle(height: height, cornerRadius: cornerRadius, isDestructive: isDestructive))
    }

    func deckCompactButton(isProminent: Bool = false, color: Color? = nil) -> some View {
        self.buttonStyle(DeckCompactButtonStyle(isProminent: isProminent, customColor: color))
    }

    func deckIconButton(size: CGFloat = DeckTheme.ControlHeight.iconRegular, cornerRadius: CGFloat = DeckTheme.CornerRadius.button, isDestructive: Bool = false) -> some View {
        self.buttonStyle(DeckIconButtonStyle(size: size, cornerRadius: cornerRadius, isDestructive: isDestructive))
    }
}
