import SwiftUI

/// WindChaser 全局视觉调色板。
///
/// 产品只支持深色模式，所有视图统一使用 `AppPalette.shared` 读取语义色，
/// 不再做日 / 夜切换。
struct AppPalette {
    static let shared = AppPalette()

    /// 主屏 / 页面底色（接近纯黑，带极轻冷色偏移）。
    let panelBackground = Color(red: 0.04, green: 0.04, blue: 0.05)

    /// 卡片背景（在底色之上稍亮一档，用于划分层次）。
    let cardBackground = Color(red: 0.09, green: 0.09, blue: 0.11)

    /// 卡片高亮区背景（用于行 hover / 选中态）。
    let elevatedBackground = Color(red: 0.13, green: 0.13, blue: 0.16)

    /// 一级文字颜色（接近纯白）。
    let primaryText = Color(red: 0.97, green: 0.97, blue: 0.99)

    /// 二级文字颜色（辅助说明、状态标签）。
    let secondaryText = Color(red: 0.58, green: 0.64, blue: 0.72)

    /// 细分隔线 / 边框（白色低透明度）。
    let borderColor = Color.white.opacity(0.08)

    /// 拖动条颜色。
    let handleColor = Color.white.opacity(0.16)

    /// 品牌强调色（霓虹绿，用于关键 CTA、就绪状态）。
    let accentColor = Color(red: 0.0, green: 0.98, blue: 0.57)

    /// 警告色（黄色，用于弱信号、电量不足等）。
    let warningColor = Color(red: 1.0, green: 0.72, blue: 0.20)

    /// 危险色（红色，用于离线、错误）。
    let dangerColor = Color(red: 0.93, green: 0.32, blue: 0.32)
}

enum MapStyleChoice {
    case standard
    case muted
}

enum RideButtonStyle {
    static let pause = Color(red: 0.96, green: 0.96, blue: 0.96)
    static let pauseForeground = Color(red: 0.15, green: 0.15, blue: 0.16)
    static let resume = Color(red: 0.66, green: 0.90, blue: 0.63)
    static let resumeForeground = Color(red: 0.12, green: 0.28, blue: 0.10)
    static let end = Color(red: 0.91, green: 0.36, blue: 0.36)
    static let endForeground = Color.white
    static let routeOrange = Color.orange
}

// MARK: - 向后兼容层（旧视图迁移期保留）

/// 旧版主题枚举。新代码请使用 `AppPalette.shared`。
///
/// 现在只剩深色一种皮肤，所有属性都代理到 `AppPalette.shared`，
/// 老视图无需立即重写也能正常工作。
enum ThemePalette: Equatable {
    case nightDark

    var panelBackground: Color { AppPalette.shared.panelBackground }
    var cardBackground: Color { AppPalette.shared.cardBackground }
    var primaryText: Color { AppPalette.shared.primaryText }
    var secondaryText: Color { AppPalette.shared.secondaryText }
    var borderColor: Color { AppPalette.shared.borderColor }
    var handleColor: Color { AppPalette.shared.handleColor }
    var accentColor: Color { AppPalette.shared.accentColor }
    var mapStyle: MapStyleChoice { .muted }
}

/// 旧版主题解析入口，永远返回深色调色板。
enum SolarTheme {
    static func palette(at _: Date = .now, latitude _: Double = 0, longitude _: Double = 0) -> ThemePalette {
        .nightDark
    }
}
