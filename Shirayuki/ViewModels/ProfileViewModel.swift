import Foundation
import Combine

/// Loads account, favorites, and notification content for the profile screen.
@MainActor
final class ProfileViewModel: ObservableViewModel {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var favorites: [ComicSummary] = []
    @Published var favoriteTotalCount: Int?
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var userProfile: UserProfileResponse?
    /// Bumped per request so a refresh discards any favorites page response still in flight.
    private var loadGeneration = 0
    
    func loadProfile() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if generation == loadGeneration { isLoading = false }
        }
        
        let profileTask = Task { try await PicaAPIService.shared.fetchUserProfile() }
        let favoritesTask = Task { try await PicaAPIService.shared.fetchFavoriteComics(page: 1, sort: .dd) }
        defer {
            profileTask.cancel()
            favoritesTask.cancel()
        }

        var resolvedError: String?

        do {
            let profile = try await profileTask.value
            guard generation == loadGeneration else { return }
            userProfile = profile
        } catch {
            guard generation == loadGeneration else { return }
            userProfile = nil
            resolvedError = error.localizedDescription
        }

        do {
            let favoritesList = try await favoritesTask.value
            guard generation == loadGeneration else { return }
            favorites = favoritesList.docs
            favoriteTotalCount = favoritesList.total
            currentPage = favoritesList.page
            totalPages = favoritesList.pages
        } catch {
            guard generation == loadGeneration else { return }
            favorites = []
            favoriteTotalCount = nil
            currentPage = 1
            totalPages = 1
            resolvedError = resolvedError ?? error.localizedDescription
        }

        errorMessage = resolvedError
    }
    
    func loadUserProfile() async {
        do {
            userProfile = try await PicaAPIService.shared.fetchUserProfile()
        } catch {
            handleError(error)
        }
    }
    
    /// Loads page 1 when resetting, otherwise the page after `currentPage`.
    /// `currentPage` only advances once that page has loaded successfully.
    func loadFavorites(reset: Bool = false) async {
        if reset {
            currentPage = 1
            favorites = []
            favoriteTotalCount = nil
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
            let result = try await PicaAPIService.shared.fetchFavoriteComics(
                page: page,
                sort: .dd
            )
            guard generation == loadGeneration else { return }
            favoriteTotalCount = result.total
            if reset {
                favorites = result.docs
            } else {
                favorites.append(contentsOf: result.docs)
            }
            currentPage = result.page
            totalPages = result.pages
        } catch {
            guard generation == loadGeneration else { return }
            handleError(error)
        }
    }
    
    func loadNextPage() async {
        guard !isLoading, currentPage < totalPages else { return }
        await loadFavorites()
    }

    /// True when a later page failed while earlier favorites are still loaded.
    var nextPageFailed: Bool {
        errorMessage != nil && !isLoading && !favorites.isEmpty
    }
    
    func punchIn() async {
        do {
            try await PicaAPIService.shared.punchIn()
            userProfile = try await PicaAPIService.shared.fetchUserProfile()
        } catch {
            handleError(error)
        }
    }

    func logout() {
        AppState.shared.logout()
    }
}
