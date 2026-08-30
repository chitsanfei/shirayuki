import Foundation
import Combine

/// Loads home discovery, ranking, and category content.
@MainActor
final class HomeViewModel: ObservableViewModel {
    @Published var comics: [ComicSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var selectedMode: HomeDisplayMode = .latest
    @Published private(set) var lastLoadedPageIDs: [String] = []
    @Published private(set) var lastEvaluatedBlockedRevision: UInt64 = 0

    var navigationTitle: String {
        selectedMode.displayName
    }

    func loadHome() async {
        await loadComics(reset: true)
    }

    func refresh() async {
        await loadComics(reset: true)
    }

    func loadComics(reset: Bool = false) async {
        if reset {
            currentPage = 1
            comics = []
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result: ComicsList
            switch selectedMode {
            case .latest:
                result = try await PicaAPIService.shared.fetchComics(payload: makePayload(page: currentPage))
            case .daily:
                result = try await PicaAPIService.shared.fetchComicRank(type: .daily)
            case .weekly:
                result = try await PicaAPIService.shared.fetchComicRank(type: .weekly)
            case .monthly:
                result = try await PicaAPIService.shared.fetchComicRank(type: .monthly)
            }
            if reset {
                comics = result.docs
            } else {
                comics.append(contentsOf: result.docs)
            }
            lastLoadedPageIDs = result.docs.map(\.id)
            currentPage = result.page
            totalPages = result.pages
        } catch {
            handleError(error)
        }
    }

    func selectMode(_ mode: HomeDisplayMode) async {
        guard selectedMode != mode else { return }
        selectedMode = mode
        await loadComics(reset: true)
    }

    func loadNextPage() async {
        guard !isLoading, currentPage < totalPages else { return }
        guard selectedMode == .latest else { return }
        currentPage += 1
        await loadComics()
    }

    func visibleComics(for snapshot: BlockedWordSnapshot) -> [ComicSummary] {
        PicaAgentAdapters.visibleComics(comics, snapshot: snapshot)
    }

    func shouldLoadFilteredPage(for snapshot: BlockedWordSnapshot) -> Bool {
        guard !isLoading, selectedMode == .latest, currentPage < totalPages else { return false }
        let latestIDs = Set(lastLoadedPageIDs)
        let latest = comics.filter { latestIDs.contains($0.id) }
        return !latest.isEmpty && PicaAgentAdapters.visibleComics(latest, snapshot: snapshot).isEmpty
    }

    func resultsHiddenAtTerminal(for snapshot: BlockedWordSnapshot) -> Bool {
        !comics.isEmpty && currentPage >= totalPages && visibleComics(for: snapshot).isEmpty
    }

    func recordBlockedRevision(_ revision: UInt64) {
        lastEvaluatedBlockedRevision = revision
    }

    private func makePayload(page: Int) -> ComicsPayload {
        ComicsPayload(
            page: page,
            c: nil,
            s: .dd,
            t: nil,
            a: nil,
            ct: nil,
            ca: nil
        )
    }
}

/// Discovery feed selected on the home screen.
enum HomeDisplayMode: String, CaseIterable, Identifiable {
    case latest
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .latest: return AppLocalization.text("home.latest")
        case .daily: return AppLocalization.text("rank.daily")
        case .weekly: return AppLocalization.text("rank.weekly")
        case .monthly: return AppLocalization.text("rank.monthly")
        }
    }

    var systemImage: String {
        switch self {
        case .latest: return "sparkles"
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar"
        case .monthly: return "moon.stars.fill"
        }
    }
}
