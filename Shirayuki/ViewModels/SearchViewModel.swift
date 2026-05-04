import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchComic] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hotKeywords: [String] = []
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var sortMode: ComicSortType = .dd
    @Published var sortAscending = false
    
    var searchHistory: [String] {
        UserDefaults.standard.stringArray(forKey: "search_history") ?? []
    }
    
    var suggestions: [String] {
        hotKeywords
    }
    
    var comics: [SearchComic] {
        results
    }
    
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
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await PicaAPIService.shared.searchComics(
                keyword: trimmedQuery,
                page: currentPage,
                sort: sortMode
            )
            if reset {
                results = result.docs
            } else {
                results.append(contentsOf: result.docs)
            }
            totalPages = result.pages
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }
    
    func loadNextPage() async {
        guard currentPage < totalPages else { return }
        currentPage += 1
        await search()
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
