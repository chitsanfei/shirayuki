import Foundation

/// Provides shared loading and error handling for observable view models.
/// This keeps identical catch blocks out of individual feature models.
@MainActor
protocol ObservableViewModel: ObservableObject {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
}

extension ObservableViewModel {
    /// Maps an arbitrary error to presentation state and ends loading.
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}