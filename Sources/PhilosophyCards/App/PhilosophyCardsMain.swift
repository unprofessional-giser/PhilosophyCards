import AppKit

/// 纯 AppKit 入口：没有 SwiftUI 的 Settings 场景，避免启动时冒出一个空白窗口。
@main
enum PhilosophyCardsMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
