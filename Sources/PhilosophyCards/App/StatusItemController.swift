import AppKit

/// 菜单栏图标：左键切换面板，右键弹出菜单。
final class StatusItemController {
    let statusItem: NSStatusItem
    private let onToggle: () -> Void
    private let menuProvider: () -> NSMenu

    var button: NSStatusBarButton? { statusItem.button }

    init(onToggle: @escaping () -> Void, menuProvider: @escaping () -> NSMenu) {
        self.onToggle = onToggle
        self.menuProvider = menuProvider
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "哲思卡片")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.toolTip = "哲思卡片 · ⌥⌘K"
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if isSecondary {
            statusItem.menu = menuProvider()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            onToggle()
        }
    }
}
