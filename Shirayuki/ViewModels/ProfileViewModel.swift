import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var favorites: [ComicDoc] = []
    @Published var favoriteTotalCount: Int?
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var userProfile: UserProfileResponse?
    
    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let profileTask = Task { try await PicaAPIService.shared.fetchUserProfile() }
        let favoritesTask = Task { try await PicaAPIService.shared.fetchFavoriteComics(page: 1, sort: .dd) }
        defer {
            profileTask.cancel()
            favoritesTask.cancel()
        }

        var resolvedError: String?

        do {
            userProfile = try await profileTask.value
        } catch {
            userProfile = nil
            resolvedError = error.localizedDescription
        }

        do {
            let favoritesList = try await favoritesTask.value
            favorites = favoritesList.docs
            favoriteTotalCount = favoritesList.total
            currentPage = favoritesList.page
            totalPages = favoritesList.pages
        } catch {
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
            errorMessage = error.localizedDescription
        }
    }
    
    func loadFavorites(reset: Bool = false) async {
        if reset {
            currentPage = 1
            favorites = []
            favoriteTotalCount = nil
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await PicaAPIService.shared.fetchFavoriteComics(
                page: currentPage,
                sort: .dd
            )
            favoriteTotalCount = result.total
            if reset {
                favorites = result.docs
            } else {
                favorites.append(contentsOf: result.docs)
            }
            totalPages = result.pages
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadNextPage() async {
        guard currentPage < totalPages else { return }
        currentPage += 1
        await loadFavorites()
    }
    
    func punchIn() async {
        do {
            try await PicaAPIService.shared.punchIn()
            userProfile = try await PicaAPIService.shared.fetchUserProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func logout() {
        AppState.shared.logout()
    }
}
