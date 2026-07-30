import Foundation
import Combine

/// Loads and publishes categories available for comic browsing.
@MainActor
final class CategoriesViewModel: ObservableViewModel {
    @Published var categories: [PicaCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadCategories() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            categories = try await PicaAPIService.shared.fetchCategories()
        } catch {
            handleError(error)
        }
    }
}
