import Foundation

/// 负责从 App Bundle 里读取 concepts.json。
/// 数据格式固定后，将来可以把 load() 换成网络请求，其余代码不需要改。
enum ConceptLibrary {
    static let fileName = "concepts"

    static func load() -> [Concept] {
        for bundle in candidateBundles {
            if let url = bundle.url(forResource: fileName, withExtension: "json"),
               let concepts = decode(url) {
                return concepts
            }
        }
        // 开发期直接从源码目录读取（直接用 swiftc 编译、没有打包资源时）。
        let devPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Model
            .deletingLastPathComponent()   // PhilosophyCards
            .appendingPathComponent("Resources/\(fileName).json")
        if let concepts = decode(devPath) {
            return concepts
        }
        NSLog("[PhilosophyCards] 未找到 concepts.json，知识库为空")
        return []
    }

    private static var candidateBundles: [Bundle] {
        #if SWIFT_PACKAGE
        return [Bundle.module, Bundle.main]
        #else
        return [Bundle.main]
        #endif
    }

    private static func decode(_ url: URL) -> [Concept]? {
        do {
            let data = try Data(contentsOf: url)
            let concepts = try JSONDecoder().decode([Concept].self, from: data)
            return concepts.isEmpty ? nil : concepts
        } catch {
            NSLog("[PhilosophyCards] 解析 \(url.path) 失败: \(error)")
            return nil
        }
    }
}
