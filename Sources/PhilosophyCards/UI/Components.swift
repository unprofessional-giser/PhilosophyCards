import SwiftUI

/// 领域小标签：彩色圆点 + 灰色文字，两种外观下都清晰。
struct CategoryChip: View {
    let category: Category

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(category.tint)
                .frame(width: 5, height: 5)
            Text(category.rawValue)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.055)))
    }
}

/// 细小的节标题，例如「定义」「通俗解释」。
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(.tertiary)
    }
}

/// 统一的图标按钮，带悬停底色。
struct IconButton: View {
    let systemName: String
    var size: CGFloat = 11
    var help: String = ""
    var tint: Color?
    var showsBackground = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(tint ?? Color.secondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(
                        Color.primary.opacity(isHovering ? 0.09 : (showsBackground ? 0.05 : 0))
                    )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

/// 主按钮：「下一个」。
struct PrimaryCapsuleButton: View {
    let title: String
    let systemImage: String
    var help: String = ""
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: systemImage)
                    .font(.system(size: 9.5, weight: .bold))
            }
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.82 : 1))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

/// 底栏上的 AI 状态小胶囊：点击进入设置。
struct AIStatusChip: View {
    let status: AppModel.AIStatus
    let action: () -> Void

    @State private var isPulsing = false

    private var isGenerating: Bool {
        if case .generating = status { return true }
        return false
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 9, weight: .semibold))
                if let label {
                    Text(label)
                        .font(.system(size: 9.5, weight: .medium))
                }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.05)))
            .opacity(isGenerating && isPulsing ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onAppear(perform: updatePulse)
        .onChange(of: isGenerating) { _ in updatePulse() }
    }

    private func updatePulse() {
        if isGenerating {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { isPulsing = false }
        }
    }

    private var iconName: String {
        switch status {
        case .failed: return "exclamationmark.triangle.fill"
        case .off, .idle, .generating: return "sparkles"
        }
    }

    private var label: String? {
        switch status {
        case .off: return "AI 设置"
        case .idle: return nil
        case .generating: return "生成中"
        case .failed: return "AI 离线"
        }
    }

    private var tint: Color {
        switch status {
        case .off: return Color.secondary.opacity(0.55)
        case .idle: return .secondary
        case .generating: return .secondary
        case .failed: return .orange
        }
    }

    private var helpText: String {
        switch status {
        case .off: return "AI 无限卡片未开启 · 点击设置"
        case .idle: return "AI 已开启，会自动续上新卡片 · 点击设置"
        case .generating: return "正在生成新的卡片…"
        case .failed(let reason): return "\(reason) · 点击设置"
        }
    }
}
