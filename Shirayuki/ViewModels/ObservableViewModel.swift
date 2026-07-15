import Foundation

/// 为所有需要展示加载状态与错误的 ViewModel 提供统一的错误处理入口，
/// 避免每个 ViewModel 重复 `catch { errorMessage = error.localizedDescription }`。
@MainActor
protocol ObservableViewModel: ObservableObject {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
}

extension ObservableViewModel {
    /// 统一错误映射：把任意 Error 写入 errorMessage 并清空加载态。
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}