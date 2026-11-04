import Foundation

/// AI 相关设置，保存在本机 Application Support 下（文件权限 600）。
struct AISettings: Codable, Equatable {
    var apiKey: String = ""
    var model: String = "deepseek-v4-pro"
    var aiEnabled: Bool = true
    var baseURL: String = "https://api.deepseek.com"

    static let availableModels: [(id: String, title: String, subtitle: String)] = [
        ("deepseek-v4-pro", "V4 Pro", "内容更稳，生成略慢"),
        ("deepseek-flash", "Flash", "更快，文风更口语")
    ]
}

enum AppPaths {
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("PhilosophyCards", isDirectory: true)
    }

    static func ensureSupportDirectory() throws {
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    }
}

enum AISettingsStore {
    static var fileURL: URL { AppPaths.supportDirectory.appendingPathComponent("settings.json") }

    static func load() -> AISettings {
        var settings = AISettings()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AISettings.self, from: data) {
            settings = decoded
        }
        // 便于开发时用环境变量覆盖，不会写回文件。
        if let envKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !envKey.isEmpty {
            settings.apiKey = envKey
        }
        return settings
    }

    static func save(_ settings: AISettings) {
        do {
            try AppPaths.ensureSupportDirectory()
            let data = try JSONEncoder().encode(settings)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            NSLog("[PhilosophyCards] 保存设置失败: \(error)")
        }
    }
}

/// AI 生成卡片的本地缓存：重启后仍然可读、可收藏，id 从 10000 起。
enum AICardCacheStore {
    static let idBase = 10_000
    static let maxCards = 300

    private struct CacheFile: Codable {
        var nextID: Int
        var cards: [Concept]
    }

    static var fileURL: URL { AppPaths.supportDirectory.appendingPathComponent("ai-cards.json") }

    static func load() -> (cards: [Concept], nextID: Int) {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(CacheFile.self, from: data) else {
            return ([], idBase)
        }
        let cards = decoded.cards.filter { $0.id >= idBase }
        let maxID = cards.map(\.id).max() ?? (idBase - 1)
        return (cards, max(decoded.nextID, maxID + 1, idBase))
    }

    static func save(cards: [Concept], nextID: Int) {
        do {
            try AppPaths.ensureSupportDirectory()
            let data = try JSONEncoder().encode(CacheFile(nextID: nextID, cards: cards))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[PhilosophyCards] 保存 AI 卡片失败: \(error)")
        }
    }
}
