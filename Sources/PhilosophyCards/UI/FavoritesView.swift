import SwiftUI

/// 收藏列表。
struct FavoritesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.hidePanel) private var hidePanel

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 20)

            if model.favorites.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            IconButton(systemName: "chevron.left", size: 11, help: "返回卡片 (Esc)") {
                model.closeFavorites()
            }
            Text("收藏")
                .font(.system(size: 16, weight: .semibold))
            Text("\(model.favorites.count)")
                .font(.system(size: 9.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.06)))

            Spacer()

            IconButton(systemName: "xmark", size: 10, help: "隐藏 (Esc)") {
                hidePanel()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var list: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 2) {
                ForEach(model.favorites) { concept in
                    FavoriteRow(
                        concept: concept,
                        onOpen: { model.show(concept) },
                        onRemove: { model.removeFavorite(concept) }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.quaternary)
            Text("还没有收藏")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("阅读时按 F，或点卡片右上角的爱心")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FavoriteRow: View {
    let concept: Concept
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(concept.category.tint)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(concept.name)
                        .font(.system(size: 13.5, weight: .medium))
                        .lineLimit(1)
                    Text(concept.en)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(concept.category.rawValue)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.quaternary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovering ? 1 : 0)
            }
            .buttonStyle(.plain)
            .help("取消收藏")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isHovering ? 0.05 : 0))
        )
        .onHover { isHovering = $0 }
    }
}
