import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var categories: [PicaCategory] = []
    @Published var comics: [ComicDoc] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var selectedCategory: String?
    
    func loadHome() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            async let categoriesTask = PicaAPIService.shared.fetchCategories()
            async let comicsTask = PicaAPIService.shared.fetchComics(payload: makePayload(page: 1))
            let (fetchedCategories, fetchedComics) = try await (categoriesTask, comicsTask)
            categories = fetchedCategories
            comics = fetchedComics.docs
            currentPage = fetchedComics.page
            totalPages = fetchedComics.pages
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func refresh() async {
        await loadHome()
    }
    
    func loadCategories() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            categories = try await PicaAPIService.shared.fetchCategories()
        } catch {
            errorMessage = error.localizedDescription
        }
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
            let result = try await PicaAPIService.shared.fetchComics(payload: makePayload(page: currentPage))
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
    
    func selectCategory(_ category: String?) async {
        guard selectedCategory != category else { return }
        selectedCategory = category
        await loadComics(reset: true)
    }
    
    func loadNextPage() async {
        guard !isLoading, currentPage < totalPages else { return }
        currentPage += 1
        await loadComics()
    }
    
    private func makePayload(page: Int) -> ComicsPayload {
        ComicsPayload(
            page: page,
            c: selectedCategory,
            s: .dd,
            t: nil,
            a: nil,
            ct: nil,
            ca: nil
        )
    }
}
