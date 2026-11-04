import Combine
import Foundation
import SwiftUI

/// 应用状态：牌组顺序、当前卡片、收藏、AI 生成与路由。
final class AppModel: ObservableObject {
    enum Route: Equatable {
        case card
        case favorites
        case settings
    }

    enum AIStatus: Equatable {
        case off
        case idle
        case generating
        case failed(String)
    }

    @Published private(set) var concepts: [Concept] = []
    @Published private(set) var aiCards: [Concept] = []
    @Published private(set) var deck: [Concept] = []
    @Published private(set) var index: Int = 0
    @Published private(set) var direction: Int = 1
    @Published private(set) var favoriteIDs: [Int] = []
    @Published private(set) var route: Route = .card
    @Published private(set) var isPinned: Bool = false
    @Published private(set) var settings: AISettings
    @Published private(set) var aiStatus: AIStatus = .off

    private let defaults: UserDefaults = .standard
    private var nextAIID: Int
    private var generationTask: Task<Void, Never>?
    private var generationTicket = UUID()
    private var lastFailureAt: Date?

    private enum Keys {
        static let favorites = "philosophy.favorites.v1"
        static let lastConcept = "philosophy.lastConcept.v1"
        static let pinned = "philosophy.pinned.v1"
    }

    /// 每次生成时随机挑几个方向，让内容不至于全挤在同一个领域。
    private static let topicHints = [
        "归因与偏见", "自我与身份", "意义与虚无", "关系与边界", "学习与动机",
        "情绪与防御", "自由与选择", "制度与规训", "依恋与亲密", "焦虑与逃避",
        "自尊与羞耻", "群体与服从", "工作与异化", "时间与死亡", "教育与成长", "语言与思维"
    ]

    init() {
        settings = AISettingsStore.load()
        let cache = AICardCacheStore.load()
        nextAIID = cache.nextID
        concepts = ConceptLibrary.load()
        aiCards = cache.cards
        favoriteIDs = defaults.array(forKey: Keys.favorites) as? [Int] ?? []
        isPinned = defaults.bool(forKey: Keys.pinned)
        rebuildDeck(showingLastConcept: true)
        refreshAIStatus()

        // 截图模式不发网络请求。
        if !CommandLine.arguments.contains("--snapshot") {
            prefetchIfNeeded()
        }
    }

    // MARK: - 派生状态

    var allCards: [Concept] { concepts + aiCards }

    var isAIEnabled: Bool { settings.aiEnabled && !settings.apiKey.isEmpty }

    var generatedCount: Int { aiCards.count }

    var current: Concept? {
        guard deck.indices.contains(index) else { return nil }
        return deck[index]
    }

    var favorites: [Concept] {
        favoriteIDs.compactMap { id in allCards.first(where: { $0.id == id }) }
    }

    func isFavorite(_ concept: Concept) -> Bool {
        favoriteIDs.contains(concept.id)
    }

    var progressText: String {
        guard !deck.isEmpty else { return "" }
        // AI 开启后牌组会一直增长，用「第 N 张」而不是分母。
        return isAIEnabled ? "第 \(index + 1) 张" : "\(index + 1) / \(deck.count)"
    }

    // MARK: - 翻卡

    func next() {
        guard !deck.isEmpty else { return }
        direction = 1
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            if index + 1 < deck.count {
                index += 1
            } else {
                reshuffleDeck(avoiding: current)
            }
        }
        saveLastConcept()
        prefetchIfNeeded()
    }

    func previous() {
        guard !deck.isEmpty else { return }
        direction = -1
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            index = index == 0 ? deck.count - 1 : index - 1
        }
        saveLastConcept()
        prefetchIfNeeded()
    }

    /// 重新打乱整个牌组，从一张新卡片开始。
    func reshuffle() {
        direction = 1
        withAnimation(.easeInOut(duration: 0.2)) {
            rebuildDeck(showingLastConcept: false)
        }
        saveLastConcept()
    }

    // MARK: - 收藏

    func toggleFavorite() {
        guard let concept = current else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let i = favoriteIDs.firstIndex(of: concept.id) {
                favoriteIDs.remove(at: i)
            } else {
                favoriteIDs.insert(concept.id, at: 0)
            }
        }
        defaults.set(favoriteIDs, forKey: Keys.favorites)
    }

    func removeFavorite(_ concept: Concept) {
        withAnimation(.easeInOut(duration: 0.18)) {
            favoriteIDs.removeAll { $0 == concept.id }
        }
        defaults.set(favoriteIDs, forKey: Keys.favorites)
    }

    // MARK: - 固定

    func togglePin() {
        isPinned.toggle()
        defaults.set(isPinned, forKey: Keys.pinned)
    }

    // MARK: - 路由

    func openFavorites() {
        withAnimation(.easeInOut(duration: 0.18)) { route = .favorites }
    }

    func closeFavorites() {
        withAnimation(.easeInOut(duration: 0.18)) { route = .card }
    }

    func toggleFavorites() {
        route == .card ? openFavorites() : closeFavorites()
    }

    func openSettings() {
        withAnimation(.easeInOut(duration: 0.18)) { route = .settings }
    }

    func closeSettings() {
        withAnimation(.easeInOut(duration: 0.18)) { route = .card }
    }

    /// 从收藏列表跳到某张卡片。
    func show(_ concept: Concept) {
        if let i = deck.firstIndex(where: { $0.id == concept.id }) {
            index = i
        } else {
            deck.insert(concept, at: 0)
            index = 0
        }
        withAnimation(.easeInOut(duration: 0.18)) { route = .card }
        saveLastConcept()
    }

    // MARK: - AI 设置

    func updateAPIKey(_ key: String) {
        let wasEmpty = settings.apiKey.isEmpty
        settings.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if wasEmpty && !settings.apiKey.isEmpty { settings.aiEnabled = true }
        AISettingsStore.save(settings)
        refreshAIStatus()
        if isAIEnabled { prefetchIfNeeded() }
    }

    func setAIEnabled(_ enabled: Bool) {
        settings.aiEnabled = enabled
        AISettingsStore.save(settings)
        refreshAIStatus()
        if enabled {
            lastFailureAt = nil
            prefetchIfNeeded()
        }
    }

    func setModel(_ model: String) {
        settings.model = model
        AISettingsStore.save(settings)
    }

    func testConnection(apiKey: String, model: String) async -> String {
        var probe = settings
        probe.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        probe.model = model
        do {
            return try await DeepSeekClient(settings: probe).ping()
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 清空 AI 生成的卡片（相关收藏一起移除），回到纯本地牌组。
    func clearAICards() {
        generationTicket = UUID()
        generationTask?.cancel()
        generationTask = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            aiCards = []
            deck.removeAll { $0.isGenerated }
            favoriteIDs.removeAll { $0 >= AICardCacheStore.idBase }
            if index >= deck.count { index = max(0, deck.count - 1) }
        }
        nextAIID = AICardCacheStore.idBase
        lastFailureAt = nil
        persistAICache()
        defaults.set(favoriteIDs, forKey: Keys.favorites)
        refreshAIStatus()
    }

    func forceGenerate() {
        lastFailureAt = nil
        startGeneration()
    }

    private func refreshAIStatus() {
        if !isAIEnabled {
            aiStatus = .off
            return
        }
        if case .generating = aiStatus { return }
        if case .failed = aiStatus { return }
        aiStatus = .idle
    }

    // MARK: - 生成

    /// 当前位置之后还有多少张 AI 卡片，掉到阈值以下就补货。
    private var unreadAICards: Int {
        guard index + 1 < deck.count else { return 0 }
        return deck[(index + 1)...].reduce(0) { $0 + ($1.isGenerated ? 1 : 0) }
    }

    private func prefetchIfNeeded() {
        guard isAIEnabled, generationTask == nil else { return }
        if let lastFailureAt, Date().timeIntervalSince(lastFailureAt) < 45 { return }
        guard unreadAICards < 6 else { return }
        startGeneration()
    }

    private func startGeneration() {
        guard isAIEnabled, generationTask == nil else { return }
        aiStatus = .generating

        let ticket = UUID()
        generationTicket = ticket
        let existing = allCards + deck
        let topics = Array(Self.topicHints.shuffled().prefix(4))
        let client = DeepSeekClient(settings: settings)

        generationTask = Task { [weak self] in
            do {
                let drafts = try await client.generateCards(count: 6, existing: existing, topics: topics)
                guard let self else { return }
                await MainActor.run {
                    self.finishGeneration(drafts, ticket: ticket)
                }
            } catch {
                guard let self else { return }
                await MainActor.run {
                    self.failGeneration(error, ticket: ticket)
                }
            }
        }
    }

    private func finishGeneration(_ drafts: [DraftCard], ticket: UUID) {
        guard ticket == generationTicket else { return }
        generationTask = nil
        var accepted: [Concept] = []
        var known = allCards + deck

        for draft in drafts {
            guard let concept = AICardValidator.makeConcept(from: draft, id: nextAIID, existing: known) else {
                continue
            }
            nextAIID += 1
            known.append(concept)
            accepted.append(concept)
        }

        NSLog("[PhilosophyCards] 生成结果：收到 \(drafts.count) 张，入库 \(accepted.count) 张")
        guard !accepted.isEmpty else {
            aiStatus = .failed("这次没有生成出可用的新卡片")
            lastFailureAt = Date()
            return
        }

        lastFailureAt = nil
        aiCards.append(contentsOf: accepted)
        // 插到当前卡片后面几张的位置，这样不用读完整个本地牌组也能读到新卡片。
        let insertAt = min(deck.count, index + 1 + Int.random(in: 3...8))
        deck.insert(contentsOf: accepted, at: insertAt)
        persistAICache()
        aiStatus = .idle
    }

    private func failGeneration(_ error: Error, ticket: UUID) {
        guard ticket == generationTicket else { return }
        generationTask = nil
        lastFailureAt = Date()
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        aiStatus = .failed(message)
    }

    private func persistAICache() {
        let favoriteSet = Set(favoriteIDs)
        if aiCards.count > AICardCacheStore.maxCards {
            var kept: [Concept] = []
            for card in aiCards.reversed() {
                if kept.count < AICardCacheStore.maxCards || favoriteSet.contains(card.id) {
                    kept.append(card)
                }
            }
            aiCards = Array(kept.reversed())
        }
        AICardCacheStore.save(cards: aiCards, nextID: nextAIID)
    }

    // MARK: - 持久化

    func persist() {
        defaults.set(favoriteIDs, forKey: Keys.favorites)
        saveLastConcept()
        persistAICache()
    }

    private func saveLastConcept() {
        if let id = current?.id {
            defaults.set(id, forKey: Keys.lastConcept)
        }
    }

    // MARK: - 牌组

    private func rebuildDeck(showingLastConcept: Bool) {
        var newDeck = allCards.shuffled()
        if showingLastConcept,
           let lastID = defaults.object(forKey: Keys.lastConcept) as? Int,
           let i = newDeck.firstIndex(where: { $0.id == lastID }) {
            newDeck.swapAt(0, i)
        }
        deck = newDeck
        index = 0
    }

    private func reshuffleDeck(avoiding previous: Concept?) {
        var newDeck = allCards.shuffled()
        if let previous, newDeck.count > 1, newDeck.first?.id == previous.id,
           let i = newDeck.lastIndex(where: { $0.id != previous.id }) {
            newDeck.swapAt(0, i)
        }
        deck = newDeck
        index = 0
    }

    // MARK: - 调试 / 截图

    func debugConfigure(conceptID: Int?, favoriteIDs ids: [Int] = []) {
        favoriteIDs = ids
        if let conceptID, let i = deck.firstIndex(where: { $0.id == conceptID }) {
            index = i
        }
    }
}
