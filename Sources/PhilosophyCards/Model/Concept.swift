import AppKit
import SwiftUI

/// 一条知识点卡片。字段与 Resources/concepts.json 一一对应。
struct Concept: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let en: String
    let definition: String
    let explanation: String
    let example: String
    let field: String

    var category: Category { Category(field) }

    /// AI 生成的卡片使用 10000 以上的 id。
    var isGenerated: Bool { id >= 10_000 }
}

/// 知识领域。数据里用中文字符串存储，新增领域时在这里扩展即可。
enum Category: String, CaseIterable, Identifiable {
    case philosophy = "哲学"
    case existentialism = "存在主义哲学"
    case social = "社会心理学"
    case personality = "人格心理学"
    case education = "教育心理学"

    var id: String { rawValue }

    init(_ raw: String) {
        self = Category(rawValue: raw) ?? .philosophy
    }

    var symbolName: String {
        switch self {
        case .philosophy: return "building.columns"
        case .existentialism: return "moon.stars"
        case .social: return "person.2"
        case .personality: return "person.crop.circle"
        case .education: return "book.closed"
        }
    }

    /// 亮/暗色模式下都有足够对比度的强调色。
    var tint: Color {
        switch self {
        case .philosophy:
            return .adaptive(light: NSColor(srgbRed: 0.36, green: 0.35, blue: 0.78, alpha: 1),
                             dark: NSColor(srgbRed: 0.65, green: 0.64, blue: 1.00, alpha: 1))
        case .existentialism:
            return .adaptive(light: NSColor(srgbRed: 0.68, green: 0.42, blue: 0.10, alpha: 1),
                             dark: NSColor(srgbRed: 0.92, green: 0.71, blue: 0.42, alpha: 1))
        case .social:
            return .adaptive(light: NSColor(srgbRed: 0.05, green: 0.47, blue: 0.44, alpha: 1),
                             dark: NSColor(srgbRed: 0.38, green: 0.83, blue: 0.78, alpha: 1))
        case .personality:
            return .adaptive(light: NSColor(srgbRed: 0.68, green: 0.22, blue: 0.36, alpha: 1),
                             dark: NSColor(srgbRed: 0.94, green: 0.55, blue: 0.66, alpha: 1))
        case .education:
            return .adaptive(light: NSColor(srgbRed: 0.16, green: 0.38, blue: 0.78, alpha: 1),
                             dark: NSColor(srgbRed: 0.52, green: 0.67, blue: 1.00, alpha: 1))
        }
    }
}

extension Color {
    /// 构造随系统外观自动切换的颜色。
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        })
    }
}
