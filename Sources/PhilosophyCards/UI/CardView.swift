import SwiftUI

/// 单张知识卡片。
struct CardView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.hidePanel) private var hidePanel

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack(alignment: .top) {
                if let concept = model.current {
                    GeometryReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            cardBody(concept)
                                .frame(minHeight: proxy.size.height, alignment: .center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .id(concept.id)
                    .transition(
                        .asymmetric(
                            insertion: .offset(x: CGFloat(model.direction) * 26).combined(with: .opacity),
                            removal: .offset(x: CGFloat(-model.direction) * 26).combined(with: .opacity)
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            footer
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: 4) {
            if let concept = model.current {
                CategoryChip(category: concept.category)
            }
            Spacer(minLength: 8)
            if let concept = model.current {
                IconButton(
                    systemName: model.isFavorite(concept) ? "heart.fill" : "heart",
                    size: 12,
                    help: "收藏 / 取消收藏 (F)",
                    tint: model.isFavorite(concept) ? concept.category.tint : nil
                ) {
                    model.toggleFavorite()
                }
            }
            IconButton(
                systemName: model.isPinned ? "pin.fill" : "pin",
                size: 11,
                help: "固定在桌面 / 取消固定",
                tint: model.isPinned ? Color.secondary : nil
            ) {
                model.togglePin()
            }
            IconButton(systemName: "xmark", size: 10, help: "隐藏面板 (Esc)；要退出 App 用 ⌘Q") {
                hidePanel()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    // MARK: - 正文

    private func cardBody(_ concept: Concept) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(concept.name)
                    .font(.system(size: 24, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(concept.en)
                    .font(.system(size: 11.5, weight: .medium))
                    .tracking(0.25)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "定义")
                Text(concept.definition)
                    .font(.system(size: 14.5, weight: .medium))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 14)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(concept.category.tint.opacity(0.8))
                            .frame(width: 3)
                            .padding(.vertical, 1)
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "通俗解释")
                Text(concept.explanation)
                    .font(.system(size: 13.5))
                    .lineSpacing(5)
                    .foregroundStyle(.primary.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }

            exampleBlock(concept)
        }
        .padding(.horizontal, Theme.padding)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exampleBlock(_ concept: Concept) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "sparkle")
                    .font(.system(size: 8.5, weight: .semibold))
                Text("例子 / 场景")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.6)
            }
            .foregroundStyle(concept.category.tint)

            Text(concept.example)
                .font(.system(size: 12.5))
                .lineSpacing(4)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }

    // MARK: - 底部

    private var footer: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                Text(model.progressText)
                    .font(.system(size: 10.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)

                AIStatusChip(status: model.aiStatus) {
                    model.openSettings()
                }

                Button {
                    model.openFavorites()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8.5))
                        Text("\(model.favorites.count)")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help("收藏列表 (T)")

                Spacer()

                IconButton(systemName: "chevron.left", size: 11, help: "上一个 (←)", showsBackground: true) {
                    model.previous()
                }

                PrimaryCapsuleButton(title: "下一个", systemImage: "arrow.right", help: "下一个 (→)") {
                    model.next()
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }
}
