import Foundation
import Combine

nonisolated enum AppImageQuality: String, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high
    case original

    static let storageKey = "app_image_quality"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return AppLocalization.text("imageQuality.low")
        case .medium: return AppLocalization.text("imageQuality.medium")
        case .high: return AppLocalization.text("imageQuality.high")
        case .original: return AppLocalization.text("imageQuality.original")
        }
    }

    static var stored: AppImageQuality {
        if let rawValue = UserDefaults.standard.string(forKey: storageKey),
           let quality = AppImageQuality(rawValue: rawValue) {
            return quality
        }
        return .original
    }
}

@MainActor
final class AppImageQualityStore: ObservableObject {
    static let shared = AppImageQualityStore()

    @Published private(set) var imageQuality: AppImageQuality

    private init() {
        imageQuality = AppImageQuality.stored
    }

    func setImageQuality(_ quality: AppImageQuality) {
        guard imageQuality != quality else { return }
        imageQuality = quality
        UserDefaults.standard.set(quality.rawValue, forKey: AppImageQuality.storageKey)
        Task(priority: .utility) {
            await ImageLoader.shared.clear()
        }
    }
}
