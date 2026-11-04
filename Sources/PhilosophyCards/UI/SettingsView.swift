import SwiftUI

/// AI 设置：Key、模型、生成状态与缓存管理。
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.hidePanel) private var hidePanel

    @State private var keyField: String = ""
    @State private var isTesting = false
    @State private var message: String?
    @State private var messageIsError = false
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 20)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    aiSection
                    keySection
                    modelSection
                    storageSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .onAppear { keyField = model.settings.apiKey }
        .alert("清空 AI 生成的卡片？", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                model.clearAICards()
                message = "已清空 AI 卡片"
                messageIsError = false
            }
        } message: {
            Text("这些卡片以及它们的收藏都会被移除，本地 65 张卡片不受影响。")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            IconButton(systemName: "chevron.left", size: 11, help: "返回卡片 (Esc)") {
                model.closeSettings()
            }
            Text("设置")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            IconButton(systemName: "xmark", size: 10, help: "隐藏 (Esc)") {
                hidePanel()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // MARK: - 区块

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "AI 无限卡片")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { model.settings.aiEnabled },
                    set: { model.setAIEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            Text("开启后，读到牌组末尾会自动调用 DeepSeek 生成新卡片，可以一直「下一个」下去。生成的卡片会缓存在本地，收藏也会保留。")
                .font(.system(size: 11))
                .lineSpacing(3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if case .failed(let reason) = model.aiStatus {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text(reason)
                        .font(.system(size: 10))
                        .lineLimit(2)
                }
                .foregroundStyle(.orange)
            }
        }
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "DeepSeek API Key")

            SecureField("sk-...", text: $keyField)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: 8) {
                SmallButton(title: "保存并启用", isPrimary: true) {
                    model.updateAPIKey(keyField)
                    message = "已保存"
                    messageIsError = false
                }

                SmallButton(title: "测试连接") {
                    testConnection()
                }

                if isTesting {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                }

                Spacer()
            }

            if let message {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(messageIsError ? Color.orange : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Key 只保存在本机：~/Library/Application Support/PhilosophyCards/settings.json（权限 600），不会写进代码仓库。")
                .font(.system(size: 9.5))
                .lineSpacing(2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "模型")
            Picker("", selection: Binding(
                get: { model.settings.model },
                set: { model.setModel($0) }
            )) {
                ForEach(AISettings.availableModels, id: \.id) { item in
                    Text(item.title).tag(item.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(model.settings.model == "deepseek-flash"
                 ? "Flash：生成快，文风更口语，偶尔概念不够严谨。"
                 : "V4 Pro：概念更稳，单次生成约 20–30 秒（在后台预生成，不耽误阅读）。")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "已生成")
            HStack {
                Text("\(model.generatedCount) 张 AI 卡片 · 本地 \(model.concepts.count) 张")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                SmallButton(title: "立即生成", isPrimary: false) {
                    model.forceGenerate()
                    message = "正在后台生成…"
                    messageIsError = false
                }
                SmallButton(title: "清空", isPrimary: false, isDestructive: true) {
                    showClearConfirmation = true
                }
            }

            HStack {
                Text("退出 App：⌘Q，或点 Dock 图标右键")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                Spacer()
                SmallButton(title: "退出", isPrimary: false) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.top, 4)
        }
    }

    private func testConnection() {
        guard !isTesting else { return }
        isTesting = true
        message = nil
        let key = keyField
        let modelID = model.settings.model

        Task {
            let result = await model.testConnection(apiKey: key, model: modelID)
            await MainActor.run {
                isTesting = false
                messageIsError = !result.hasPrefix("已连接")
                message = result
            }
        }
    }
}

/// 设置页里的小胶囊按钮。
private struct SmallButton: View {
    let title: String
    var isPrimary: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(foreground)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(background)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        if isPrimary { return Color(nsColor: .windowBackgroundColor) }
        if isDestructive { return .red.opacity(0.9) }
        return .primary
    }

    private var background: Color {
        if isPrimary { return Color.primary.opacity(isHovering ? 0.85 : 1) }
        return Color.primary.opacity(isHovering ? 0.10 : 0.06)
    }
}
