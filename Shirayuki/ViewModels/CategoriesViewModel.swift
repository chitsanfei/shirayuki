import Foundation
import Combine

@MainActor
final class CategoriesViewModel: ObservableObject {
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
            errorMessage = error.localizedDescription
        }
    }
}
