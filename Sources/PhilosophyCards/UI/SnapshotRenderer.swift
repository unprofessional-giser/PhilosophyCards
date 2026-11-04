import AppKit
import SwiftUI

/// 开发期把界面渲染成 PNG，用来检查亮色 / 暗色下的排版。
/// 用法：PhilosophyCards --snapshot /tmp/shots
enum SnapshotRenderer {
    static func render(model: AppModel, to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        model.debugConfigure(conceptID: 12, favoriteIDs: [12, 5, 13, 45, 62, 23])

        var report: [String] = []

        for scheme in [ColorScheme.light, ColorScheme.dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            NSApp.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)

            model.closeFavorites()
            let cardURL = directory.appendingPathComponent("card-\(suffix).png")
            report.append("card-\(suffix): \(render(view(model, scheme), to: cardURL) ? "ok" : "failed")")

            model.openFavorites()
            let favoritesURL = directory.appendingPathComponent("favorites-\(suffix).png")
            report.append("favorites-\(suffix): \(render(view(model, scheme), to: favoritesURL) ? "ok" : "failed")")

            model.openSettings()
            let settingsURL = directory.appendingPathComponent("settings-\(suffix).png")
            report.append("settings-\(suffix): \(render(view(model, scheme), to: settingsURL) ? "ok" : "failed")")
        }

        model.closeSettings()
        if let aiCard = model.aiCards.last {
            NSApp.appearance = NSAppearance(named: .darkAqua)
            model.debugConfigure(conceptID: aiCard.id, favoriteIDs: [aiCard.id])
            let aiURL = directory.appendingPathComponent("ai-card-dark.png")
            report.append("ai-card-dark: \(render(view(model, .dark), to: aiURL) ? "ok" : "failed")")
        }

        model.closeFavorites()
        NSLog("[PhilosophyCards] snapshot -> \(report.joined(separator: ", "))")
    }

    private static func view(_ model: AppModel, _ scheme: ColorScheme) -> some View {
        RootView()
            .environmentObject(model)
            .environment(\.colorScheme, scheme)
            .environment(\.hidePanel, {})
    }

    private static func render(_ view: some View, to url: URL) -> Bool {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: Theme.width, height: Theme.height)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return false }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            NSLog("[PhilosophyCards] 写入 \(url.path) 失败: \(error)")
            return false
        }
    }
}
