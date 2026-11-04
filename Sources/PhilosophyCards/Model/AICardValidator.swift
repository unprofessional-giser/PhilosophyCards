import Foundation

/// AI 卡片入库前的清理与查重。
enum AICardValidator {
    static func makeConcept(from draft: DraftCard, id: Int, existing: [Concept]) -> Concept? {
        let name = clean(draft.name)
        let en = clean(draft.en)
        let definition = clean(draft.definition)
        let explanation = clean(draft.explanation)
        let example = clean(draft.example)

        guard let category = normalizeField(draft.field),
              (2...24).contains(name.count),
              (3...90).contains(en.count),
              (6...80).contains(definition.count),
              (40...240).contains(explanation.count),
              (10...200).contains(example.count),
              !isDuplicate(name: name, en: en, existing: existing)
        else { return nil }

        return Concept(
            id: id,
            name: name,
            en: en,
            definition: definition,
            explanation: explanation,
            example: example,
            field: category.rawValue
        )
    }

    static func isDuplicate(name: String, en: String, existing: [Concept]) -> Bool {
        let nameKey = normalize(name)
        let enKey = normalize(en)
        let enTokens = tokens(en)

        for card in existing {
            let existingNameKey = normalize(card.name)
            let existingEnKey = normalize(card.en)

            if nameKey == existingNameKey || enKey == existingEnKey { return true }

            // 中文名互相包含（「共情边界」vs「边界」、「最近发展区」vs「发展区」）
            if nameKey.count >= 2, existingNameKey.count >= 2 {
                if nameKey.contains(existingNameKey) || existingNameKey.contains(nameKey) { return true }
            }

            // 英文名高度重合（「Self-Serving Bias」vs「Self Serving Bias」以外的近义写法）
            let existingTokens = tokens(card.en)
            if enTokens.count >= 2, existingTokens.count >= 2 {
                let shared = enTokens.intersection(existingTokens).count
                let union = enTokens.union(existingTokens).count
                if union > 0, Double(shared) / Double(union) >= 0.75 { return true }
            }

            // 中文名只差一两个字
            if similarity(nameKey, existingNameKey) >= 0.8 { return true }
        }
        return false
    }

    // MARK: - 工具

    private static func clean(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”「」")))
    }

    private static func normalizeField(_ raw: String) -> Category? {
        let value = clean(raw)
        if let exact = Category(rawValue: value) { return exact }
        for category in Category.allCases where value.contains(category.rawValue) {
            return category
        }
        if value.contains("存在") { return .existentialism }
        if value.contains("社会") { return .social }
        if value.contains("人格") || value.contains("精神分析") { return .personality }
        if value.contains("教育") || value.contains("学习") { return .education }
        if value.contains("哲学") { return .philosophy }
        return nil
    }

    private static func normalize(_ text: String) -> String {
        let scalars = text.lowercased().unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || (0x4E00...0x9FFF).contains(scalar.value)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private static func tokens(_ en: String) -> Set<String> {
        let stopWords: Set<String> = ["of", "the", "a", "an", "and", "in", "to", "for", "on", "with"]
        let parts = en.lowercased().split { !$0.isLetter }
        return Set(parts.map(String.init).filter { $0.count > 2 && !stopWords.contains($0) })
    }

    /// 1 - 编辑距离 / 较长字符串长度。
    private static func similarity(_ a: String, _ b: String) -> Double {
        let x = Array(a)
        let y = Array(b)
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        var previous = Array(0...y.count)
        var current = [Int](repeating: 0, count: y.count + 1)

        for i in 1...x.count {
            current[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        let distance = Double(previous[y.count])
        return 1 - distance / Double(max(x.count, y.count))
    }
}
