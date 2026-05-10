import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var comics: [ComicDoc] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var selectedMode: HomeDisplayMode = .latest

    var navigationTitle: String {
        selectedMode.displayName
    }

    func loadHome() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await PicaAPIService.shared.fetchComics(payload: makePayload(page: 1))
            comics = result.docs
            currentPage = result.page
            totalPages = result.pages
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await selectMode(selectedMode)
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
            currentPage = result.page
            totalPages = result.pages
        } catch {
            errorMessage = error.localizedDescription
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
}
