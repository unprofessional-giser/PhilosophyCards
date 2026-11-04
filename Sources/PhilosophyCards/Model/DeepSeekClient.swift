import Foundation

/// AI 返回的原始卡片，尚未分配本地 id。
struct DraftCard: Codable {
    let name: String
    let en: String
    let definition: String
    let explanation: String
    let example: String
    let field: String
}

enum AIError: LocalizedError {
    case missingKey
    case http(Int, String)
    case badResponse(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "还没有设置 API Key"
        case .http(let code, let body):
            switch code {
            case 401: return "API Key 无效"
            case 402: return "API 余额不足"
            case 429: return "请求太频繁，稍后再试"
            case 500...599: return "服务暂时不可用（\(code)）"
            default: return "API 返回 \(code)\(body.isEmpty ? "" : "：\(body.prefix(60))")"
            }
        case .badResponse(let detail):
            return "AI 返回异常：\(detail)"
        case .empty:
            return "AI 没有返回卡片"
        }
    }
}

/// 直接调用 DeepSeek 的 OpenAI 兼容接口，用来源源不断地生成新卡片。
struct DeepSeekClient {
    let settings: AISettings
    var session: URLSession = .shared

    // MARK: - 生成

    func generateCards(count: Int, existing: [Concept], topics: [String]) async throws -> [DraftCard] {
        guard !settings.apiKey.isEmpty else { throw AIError.missingKey }

        let messages: [[String: Any]] = [
            ["role": "system", "content": Self.systemPrompt(existing: existing)],
            ["role": "user", "content": Self.userPrompt(count: count, topics: topics)]
        ]

        var payload: [String: Any] = [
            "model": settings.model,
            "messages": messages,
            "temperature": 0.95,
            "max_tokens": 6000,
            "response_format": ["type": "json_object"],
            "thinking": ["type": "disabled"]
        ]

        var data: Data
        do {
            data = try await send(payload)
        } catch AIError.http(400, _) {
            // 有些兼容接口不认识 thinking 参数，去掉后再试一次。
            payload.removeValue(forKey: "thinking")
            payload["max_tokens"] = 8000
            data = try await send(payload)
        }

        let drafts = try Self.parseDrafts(from: data)
        let invalid = await verifyNames(drafts)
        if !invalid.isEmpty {
            NSLog("[PhilosophyCards] 审核剔除：\(invalid.joined(separator: "、"))")
        }
        // 审稿结果可能带英文括注（「工作狂迷思（Workaholism）」），用包含匹配更稳。
        return drafts.filter { draft in
            !invalid.contains { marked in
                marked.contains(draft.name) || draft.name.contains(marked)
            }
        }
    }

    /// 第二遍审核：把生造的、只是描述性短语的「概念」筛掉。
    /// 审核失败时放行（宁可少拦，也不要因为网络问题一张卡片都拿不到）。
    private func verifyNames(_ drafts: [DraftCard]) async -> Set<String> {
        guard !drafts.isEmpty else { return [] }
        let list = drafts.map { "- \($0.name)（\($0.en)）· 领域：\($0.field)" }.joined(separator: "\n")
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一位严格的概念审稿人。你只输出 JSON。"],
            ["role": "user", "content": """
            下面是从哲学、存在主义哲学、社会心理学、人格心理学、教育学里选出的候选概念：

            \(list)

            判断每一个是否是学界真实存在的通行概念。以下任意一条不满足，都算无效：
            1. 有明确提出者，或能在教科书 / 百科里查到条目；
            2. 中文名是通行的译名，不是生硬直译或自创（如把 Terror Management Theory 写成「恐慌管理」）；
            3. 标出的领域与概念实际所属领域一致（如「语言相对论」不应归到人格心理学）。

            生造的、只是描述性短语的、把某个理论改写成论文标题的，也都算无效。
            只输出 JSON：{"invalid":["无效的概念名"],"reason":{"概念名":"一句话原因"}}
            """]
        ]
        let payload: [String: Any] = [
            "model": settings.model,
            "messages": messages,
            "temperature": 0,
            "max_tokens": 2000,
            "response_format": ["type": "json_object"],
            "thinking": ["type": "disabled"]
        ]

        do {
            let data = try await send(payload)
            guard let raw = try? JSONSerialization.jsonObject(with: data),
                  let object = raw as? [String: Any],
                  let choices = object["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String,
                  let start = content.firstIndex(of: "{"),
                  let end = content.lastIndex(of: "}"),
                  let jsonData = String(content[start...end]).data(using: .utf8),
                  let verdict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let invalid = verdict["invalid"] as? [String] else {
                return []
            }
            return Set(invalid.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        } catch {
            return []
        }
    }

    /// 用来在设置页测试连通性。
    func ping() async throws -> String {
        guard !settings.apiKey.isEmpty else { throw AIError.missingKey }
        guard let url = URL(string: baseURLString + "/models") else { throw AIError.badResponse("URL 无效") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse("没有响应") }
        guard (200..<300).contains(http.statusCode) else {
            throw AIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        if let raw = try? JSONSerialization.jsonObject(with: data),
           let object = raw as? [String: Any],
           let models = object["data"] as? [[String: Any]] {
            let ids = models.compactMap { $0["id"] as? String }
            if ids.contains(settings.model) { return "已连接 · \(settings.model)" }
            if !ids.isEmpty { return "已连接 · 可用模型：\(ids.joined(separator: ", "))" }
        }
        return "已连接"
    }

    // MARK: - 网络

    private var baseURLString: String {
        var base = settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        return base.isEmpty ? "https://api.deepseek.com" : base
    }

    private func send(_ payload: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURLString + "/chat/completions") else {
            throw AIError.badResponse("URL 无效")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse("没有响应") }
        guard (200..<300).contains(http.statusCode) else {
            throw AIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    // MARK: - 解析

    private static func parseDrafts(from data: Data) throws -> [DraftCard] {
        guard let raw = try? JSONSerialization.jsonObject(with: data),
              let object = raw as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty else {
            throw AIError.empty
        }

        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}") else {
            throw AIError.badResponse("没有 JSON")
        }
        let jsonString = String(content[start...end])
        guard let jsonData = jsonString.data(using: .utf8) else { throw AIError.badResponse("编码失败") }

        struct Payload: Decodable { let concepts: [DraftCard] }
        do {
            return try JSONDecoder().decode(Payload.self, from: jsonData).concepts
        } catch {
            throw AIError.badResponse("字段不完整")
        }
    }

    // MARK: - Prompt

    private static func systemPrompt(existing: [Concept]) -> String {
        let limited: [Concept]
        if existing.count > 220 {
            limited = Array(existing.prefix(120)) + Array(existing.suffix(100))
        } else {
            limited = existing
        }
        let list = limited.map { "\($0.name)（\($0.en)）" }.joined(separator: "；")

        return """
        你是一位很会讲话的写作者，为一位聪明但疲惫的成年人解释概念。领域：哲学、存在主义哲学、社会心理学、人格心理学、教育心理学。

        你写的是解释，不是教科书条目。不要使用「个体」「认知机制」「内化」「范式」这类学术词。

        硬性规则：
        1. 只选有明确提出者、或教科书里能查到的通行概念。不要生造术语，不要把某个理论改写成论文标题式的新名字（比如「关系性沉默」「意义协商」这类）。
        2. 中文名要像词典条目：2-8 个字的名词短语，不含「的」。
        3. 不要与下面已有概念重复，也包括同义、近义、只是换了中文名的：
        \(list)
        4. 只输出 JSON，不要解释。
        """
    }

    private static func userPrompt(count: Int, topics: [String]) -> String {
        """
        生成 \(count) 个新的知识卡片，主题围绕：\(topics.joined(separator: "、"))。

        写作要求：
        1. definition：一句话，30 字以内，直接说清是什么。
        2. explanation：90-150 字。第一句说这个现象长什么样，中间说为什么会发生，最后一句说它带来的代价或提醒。像跟朋友聊天，不要分点，不要说教。
        3. example：40-80 字，一个当代生活里的具体场景，最好带有动作或对话。
        4. field 只能是：哲学 / 存在主义哲学 / 社会心理学 / 人格心理学 / 教育心理学，尽量分散。
        5. en 必须是英文学界能检索到的通行名称；叫不出公认英文名就换一个概念。

        只输出 JSON，不要其他文字：
        {"concepts":[{"name":"中文名","en":"English Name","definition":"...","explanation":"...","example":"...","field":"社会心理学"}]}
        """
    }
}
