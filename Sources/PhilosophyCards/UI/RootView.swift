import SwiftUI

/// 面板根视图：负责背景、圆角、剪裁，以及「卡片 / 收藏」两个页面之间的切换。
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            background
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: Theme.width, height: Theme.height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07), lineWidth: 1)
        )
    }

    private var background: some View {
        let tint = model.current?.category.tint ?? Category.philosophy.tint
        return ZStack(alignment: .top) {
            Theme.panelBackground
            LinearGradient(
                colors: [tint.opacity(colorScheme == .dark ? 0.10 : 0.05), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 230)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.concepts.isEmpty {
            EmptyDeckView()
        } else {
            switch model.route {
            case .card:
                CardView()
            case .favorites:
                FavoritesView()
            case .settings:
                SettingsView()
            }
        }
    }
}

/// 知识库加载失败时的兜底界面。
struct EmptyDeckView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.quaternary)
            Text("没有加载到知识库")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("请确认 Resources/concepts.json 已打包进 App")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
