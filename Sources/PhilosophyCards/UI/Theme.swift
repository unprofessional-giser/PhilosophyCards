import AppKit
import SwiftUI

enum Theme {
    static let width: CGFloat = 456
    static let height: CGFloat = 512
    static let corner: CGFloat = 20
    static let padding: CGFloat = 24

    /// 面板底色：亮色接近纸白，暗色接近石墨。
    static var panelBackground: Color {
        .adaptive(
            light: NSColor(srgbRed: 0.984, green: 0.980, blue: 0.973, alpha: 1),
            dark: NSColor(srgbRed: 0.106, green: 0.110, blue: 0.122, alpha: 1)
        )
    }
}

// MARK: - 隐藏面板的动作，由 PanelController 注入

private struct HidePanelKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var hidePanel: () -> Void {
        get { self[HidePanelKey.self] }
        set { self[HidePanelKey.self] = newValue }
    }
}
