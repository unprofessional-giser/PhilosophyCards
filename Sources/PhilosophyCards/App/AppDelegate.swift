import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var panelController: PanelController!
    private var statusController: StatusItemController!
    private let hotKey = GlobalHotKey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 常规 App：Dock 里能看到图标，⌘Q 可以退出，点击 Dock 图标可以重新呼出面板。
        NSApp.setActivationPolicy(.regular)
        buildMainMenu()

        model = AppModel()
        panelController = PanelController(model: model)
        statusController = StatusItemController(
            onToggle: { [weak self] in self?.panelController.toggle() },
            menuProvider: { [weak self] in self?.makeMenu() ?? NSMenu() }
        )
        panelController.anchorButton = statusController.button

        hotKey.register(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(cmdKey | optionKey)
        ) { [weak self] in
            self?.panelController.toggle()
        }

        if let directory = snapshotDirectory() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                SnapshotRenderer.render(model: self.model, to: directory)
                NSApp.terminate(nil)
            }
            return
        }

        if CommandLine.arguments.contains("--diagnose") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let windows = NSApp.windows.map { "\(type(of: $0)) visible=\($0.isVisible) title=\($0.title)" }
                NSLog("[DIAG] policy=\(NSApp.activationPolicy().rawValue) windows=\(windows)")
                NSApp.terminate(nil)
            }
            return
        }

        // 启动时自动展示一次，让用户第一眼知道它在哪里。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.panelController.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.persist()
    }

    func applicationDidResignActive(_ notification: Notification) {
        panelController?.handleAppDeactivated()
    }

    /// 从 Finder / Dock 再次激活 App 时，把面板叫回来，而不是让用户以为它没打开。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController?.show()
        return true
    }

    /// 右键 Dock 图标时的快捷菜单。
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        addItem(to: menu, title: "显示卡片", action: #selector(showPanel))
        addItem(to: menu, title: "下一个概念", action: #selector(nextConcept))
        addItem(to: menu, title: "收藏列表", action: #selector(openFavorites))
        addItem(to: menu, title: "AI 设置…", action: #selector(openAISettings))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出哲思卡片", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    // MARK: - 主菜单

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "哲思卡片")
        appMenu.addItem(withTitle: "关于哲思卡片", action: #selector(showAboutPanel), keyEquivalent: "")
        appMenu.addItem(.separator())
        addItem(to: appMenu, title: "显示卡片", action: #selector(showPanel))
        addItem(to: appMenu, title: "下一个概念", action: #selector(nextConcept))
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "退出哲思卡片", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        appMenu.addItem(quit)
        appMenuItem.submenu = appMenu

        // 没有编辑菜单的话，设置页里的 ⌘V 粘贴 API Key 会失效。
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "哲思卡片",
            .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            .credits: NSAttributedString(string: "每天读一个概念，读到读不完为止。", attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 菜单栏菜单

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let current = model.current

        let header = NSMenuItem(
            title: current.map { "当前：\($0.name)" } ?? "知识库为空",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        addItem(to: menu, title: panelController.isVisible ? "隐藏卡片" : "显示卡片", action: #selector(togglePanel))
        addItem(to: menu, title: "下一个概念", action: #selector(nextConcept))

        if let current {
            let title = model.isFavorite(current) ? "取消收藏：\(current.name)" : "收藏：\(current.name)"
            addItem(to: menu, title: title, action: #selector(toggleFavorite))
        }

        addItem(to: menu, title: "收藏列表（\(model.favorites.count)）", action: #selector(openFavorites))
        addItem(to: menu, title: "AI 设置…", action: #selector(openAISettings))
        addItem(to: menu, title: "立即生成新卡片", action: #selector(generateCards))
        addItem(to: menu, title: "重新打乱牌组", action: #selector(reshuffleDeck))
        addItem(to: menu, title: "窗口回到菜单栏下方", action: #selector(resetPanelPosition))
        addItem(to: menu, title: model.isPinned ? "取消固定" : "固定在桌面", action: #selector(togglePin))

        menu.addItem(.separator())

        let shortcut = NSMenuItem(
            title: hotKey.isRegistered ? "快捷键：⌥⌘K 呼出 / 隐藏" : "快捷键注册失败，请用菜单栏图标",
            action: nil,
            keyEquivalent: ""
        )
        shortcut.isEnabled = false
        menu.addItem(shortcut)

        let quit = NSMenuItem(title: "退出哲思卡片（⌘Q）", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)

        return menu
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func showPanel() {
        panelController?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }

    @objc private func nextConcept() {
        model.next()
        panelController.show()
    }

    @objc private func toggleFavorite() {
        model.toggleFavorite()
    }

    @objc private func openAISettings() {
        model.openSettings()
        panelController.show()
    }

    @objc private func generateCards() {
        model.forceGenerate()
        panelController.show()
    }

    @objc private func openFavorites() {
        model.openFavorites()
        panelController.show()
    }

    @objc private func reshuffleDeck() {
        model.reshuffle()
        panelController.show()
    }

    @objc private func resetPanelPosition() {
        panelController.resetPosition()
        panelController.show()
    }

    @objc private func togglePin() {
        model.togglePin()
        if !panelController.isVisible { panelController.show() }
    }

    // MARK: - 截图模式

    private func snapshotDirectory() -> URL? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--snapshot"), args.count > index + 1 else { return nil }
        return URL(fileURLWithPath: args[index + 1])
    }
}
