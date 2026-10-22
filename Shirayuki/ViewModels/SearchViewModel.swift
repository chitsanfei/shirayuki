import Foundation
import Combine

/// Owns search query, filters, pagination, suggestions, and history.
@MainActor
final class SearchViewModel: ObservableViewModel {
    @Published var query: String = ""
    @Published var results: [ComicSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hotKeywords: [String] = []
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var sortMode: ComicSortType = .dd
    @Published var sortAscending = false
    @Published private(set) var lastLoadedPageIDs: [String] = []
    @Published private(set) var lastEvaluatedBlockedRevision: UInt64 = 0
    /// Bumped per request so a new search discards any page response still in flight.
    private var loadGeneration = 0
    
    var searchHistory: [String] {
        UserDefaults.standard.stringArray(forKey: "search_history") ?? []
    }
    
    var suggestions: [String] {
        hotKeywords
    }
    
    var comics: [ComicSummary] {
        results
    }

    /// PicACG exposes date ascending as `da`; other sort modes are already directional.
    nonisolated static func resolvedSortMode(
        sortMode: ComicSortType,
        ascending: Bool
    ) -> ComicSortType {
        ascending && sortMode == .dd ? .da : sortMode
    }

    var requestSortMode: ComicSortType {
        Self.resolvedSortMode(sortMode: sortMode, ascending: sortAscending)
    }
    
    /// Loads page 1 when resetting, otherwise the page after `currentPage`.
    /// `currentPage` only advances once that page has loaded successfully.
    func search(reset: Bool = false) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            clearQuery()
            return
        }
        
        if reset {
            currentPage = 1
            results = []
            saveSearchHistory(trimmedQuery)
        }
        let page = reset ? 1 : currentPage + 1
        
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if generation == loadGeneration { isLoading = false }
        }
        do {
            let result = try await PicaAPIService.shared.searchComics(
                keyword: trimmedQuery,
                page: page,
                sort: requestSortMode
            )
            guard generation == loadGeneration else { return }
            if reset {
                results = result.docs
            } else {
                results.append(contentsOf: result.docs)
            }
            lastLoadedPageIDs = result.docs.map(\.id)
            currentPage = result.page
            totalPages = result.pages
        } catch {
            guard generation == loadGeneration else { return }
            handleError(error)
        }
    }
    
    func loadNextPage() async {
        guard !isLoading, currentPage < totalPages else { return }
        await search()
    }

    /// True when a later page failed while earlier results are still on screen.
    var nextPageFailed: Bool {
        errorMessage != nil && !isLoading && !results.isEmpty
    }

    func visibleComics(for snapshot: BlockedWordSnapshot) -> [ComicSummary] {
        PicaAgentAdapters.visibleComics(results, snapshot: snapshot)
    }

    func shouldLoadFilteredPage(for snapshot: BlockedWordSnapshot) -> Bool {
        guard !isLoading, errorMessage == nil, currentPage < totalPages else { return false }
        let latestIDs = Set(lastLoadedPageIDs)
        let latest = results.filter { latestIDs.contains($0.id) }
        return !latest.isEmpty && PicaAgentAdapters.visibleComics(latest, snapshot: snapshot).isEmpty
    }

    func resultsHiddenAtTerminal(for snapshot: BlockedWordSnapshot) -> Bool {
        !results.isEmpty && currentPage >= totalPages && visibleComics(for: snapshot).isEmpty
    }

    func recordBlockedRevision(_ revision: UInt64) {
        lastEvaluatedBlockedRevision = revision
    }
    
    func loadHotKeywords() async {
        do {
            hotKeywords = try await PicaAPIService.shared.fetchHotSearchWords()
        } catch {
            hotKeywords = []
        }
    }
    
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: "search_history")
        objectWillChange.send()
    }
    
    func clearQuery() {
        loadGeneration += 1
        isLoading = false
        query = ""
        results = []
        errorMessage = nil
    }
    
    private func saveSearchHistory(_ keyword: String) {
        var history = UserDefaults.standard.stringArray(forKey: "search_history") ?? []
        history.removeAll { $0 == keyword }
        history.insert(keyword, at: 0)
        if history.count > 20 { history = Array(history.prefix(20)) }
        UserDefaults.standard.set(history, forKey: "search_history")
    }
}
