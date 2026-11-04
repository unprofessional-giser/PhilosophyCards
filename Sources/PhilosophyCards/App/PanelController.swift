import AppKit
import SwiftUI

/// 无边框浮动面板：可以成为 key window（这样才能接收键盘），但不激活整个 App。
final class CardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 管理浮动卡片面板的显示、定位与键盘交互。
final class PanelController {
    let panel: CardPanel
    private let model: AppModel

    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var moveObserver: NSObjectProtocol?
    private var isProgrammaticMove = false
    private var shownAt = Date.distantPast
    private var lastAutoHide = Date.distantPast
    /// 刚打开的一小段时间里不自动收起，避免启动 / 激活时的焦点抖动把它关掉。
    private var hideSuppressionUntil = Date.distantPast
    /// 用来取消「正在进行的隐藏动画」，避免旧动画把刚重新打开的面板关掉。
    private var visibilityToken = UUID()
    private var isHiding = false

    /// 菜单栏图标按钮，用来把面板对齐到图标下方。
    weak var anchorButton: NSStatusBarButton?

    var isVisible: Bool { panel.isVisible }

    init(model: AppModel) {
        self.model = model

        let size = NSSize(width: Theme.width, height: Theme.height)
        let panel = CardPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel = panel

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setContentSize(size)

        let root = RootView()
            .environmentObject(model)
            .environment(\.hidePanel, { [weak self] in self?.hide() })

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        panel.contentView = hosting

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.handleResignKey()
        }

        // 用户拖动过面板后，下次打开记住位置。
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard let self, !self.isProgrammaticMove else { return }
            let origin = self.panel.frame.origin
            UserDefaults.standard.set([origin.x, origin.y], forKey: Self.savedOriginKey)
        }

        installKeyMonitor()
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
    }

    // MARK: - 显示 / 隐藏

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            // 点击菜单栏会让面板先失焦隐藏，这里避免同一次点击又把它打开。
            if Date().timeIntervalSince(lastAutoHide) < 0.35 {
                lastAutoHide = .distantPast
                return
            }
            show()
        }
    }

    func show() {
        visibilityToken = UUID()
        isHiding = false

        if !panel.isVisible {
            positionPanel()
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.makeKey()
        }
        shownAt = Date()
        hideSuppressionUntil = Date().addingTimeInterval(0.9)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide(automatic: Bool = false) {
        guard panel.isVisible, !isHiding else { return }
        isHiding = true
        if automatic { lastAutoHide = Date() }

        let token = UUID()
        visibilityToken = token

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.visibilityToken == token else { return }
            self.isHiding = false
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
            if self.model.route != .card {
                self.model.closeFavorites()
            }
        }
    }

    private func handleResignKey() {
        guard !model.isPinned, panel.isVisible else { return }
        guard Date().timeIntervalSince(shownAt) > 0.2 else { return }
        // App 自己还是激活状态时（点 Dock、打开菜单、弹窗），不要因为失焦就收起面板。
        // 真正切到别的 App 的情况由 applicationDidResignActive 处理。
        guard !NSApp.isActive else { return }
        guard Date() >= hideSuppressionUntil else { return }
        hide(automatic: true)
    }

    /// 用户切换到别的 App 时收起面板（固定状态下不收起）。
    func handleAppDeactivated() {
        guard !model.isPinned, panel.isVisible else { return }
        guard Date() >= hideSuppressionUntil else { return }
        hide(automatic: true)
    }

    // MARK: - 定位

    static let savedOriginKey = "philosophy.panelOrigin.v1"

    func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.savedOriginKey)
        if panel.isVisible { positionPanel() }
    }

    private func positionPanel() {
        let size = panel.frame.size
        guard let screen = anchorButton?.window?.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame

        if let saved = savedOrigin(),
           let target = NSScreen.screens.first(where: {
               $0.visibleFrame.intersects(NSRect(origin: saved, size: size))
           }) {
            moveProgrammatically(to: saved.clamped(in: target.visibleFrame, size: size))
            return
        }

        var origin: NSPoint
        if let button = anchorButton, let window = button.window {
            let rectInWindow = button.convert(button.bounds, to: nil)
            let rectOnScreen = window.convertToScreen(rectInWindow)
            origin = NSPoint(
                x: rectOnScreen.midX - size.width / 2,
                y: rectOnScreen.minY - size.height - 8
            )
        } else {
            origin = NSPoint(
                x: visible.maxX - size.width - 16,
                y: visible.maxY - size.height - 16
            )
        }

        moveProgrammatically(to: origin.clamped(in: visible, size: size))
    }

    private func moveProgrammatically(to origin: NSPoint) {
        isProgrammaticMove = true
        panel.setFrameOrigin(origin)
        DispatchQueue.main.async { [weak self] in
            self?.isProgrammaticMove = false
        }
    }

    private func savedOrigin() -> NSPoint? {
        guard let values = UserDefaults.standard.array(forKey: Self.savedOriginKey) as? [Double],
              values.count == 2 else { return nil }
        return NSPoint(x: values[0], y: values[1])
    }

    // MARK: - 键盘

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.panel.isVisible, self.panel.isKeyWindow else { return event }
            return self.handleKey(event)
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        // 正在输入 API Key 时，把按键交还给文本框。
        if let responder = panel.firstResponder, responder is NSTextView {
            return event
        }

        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "d":
                if model.route == .card { model.toggleFavorite() }
                return nil
            case "w":
                hide()
                return nil
            default:
                return event
            }
        }

        // Esc：设置 → 收藏 → 卡片，逐层退出，最后一层收起面板。
        if event.keyCode == 53 {
            switch model.route {
            case .settings: model.closeSettings()
            case .favorites: model.closeFavorites()
            case .card: hide()
            }
            return nil
        }

        // 设置页只响应 Esc，其余按键留给输入控件。
        guard model.route != .settings else { return event }

        if event.keyCode == 48 { // tab
            model.toggleFavorites()
            return nil
        }

        if model.route == .card {
            switch event.keyCode {
            case 124: // →
                model.next()
                return nil
            case 123: // ←
                model.previous()
                return nil
            default:
                break
            }

            switch event.charactersIgnoringModifiers?.lowercased() {
            case "n", " ":
                model.next()
                return nil
            case "p":
                model.previous()
                return nil
            case "f":
                model.toggleFavorite()
                return nil
            case "t":
                model.openFavorites()
                return nil
            default:
                break
            }
        }

        return event
    }
}


private extension NSPoint {
    /// 把窗口位置限制在屏幕可见区域内。
    func clamped(in visible: NSRect, size: NSSize) -> NSPoint {
        let minX = visible.minX + 12
        let maxX = visible.maxX - size.width - 12
        let minY = visible.minY + 12
        let maxY = visible.maxY - size.height - 12
        return NSPoint(
            x: min(max(x, minX), max(minX, maxX)),
            y: min(max(y, minY), max(minY, maxY))
        )
    }
}
