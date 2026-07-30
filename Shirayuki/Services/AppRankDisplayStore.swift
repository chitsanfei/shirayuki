import Foundation
import Combine

/// Metadata shown beneath comics in ranking lists.
enum RankMetadataDisplay: String, CaseIterable, Identifiable, Sendable {
    case categories
    case tags

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .categories: return "settings.rank.display.categories"
        case .tags: return "settings.rank.display.tags"
        }
    }
}

/// Persists and publishes ranking-card display preferences.
@MainActor
final class AppRankDisplayStore: ObservableObject {
    static let shared = AppRankDisplayStore()

    static let displayKey = "rank_metadata_display"
    static let tagCountKey = "rank_max_tag_count"

    @Published private(set) var display: RankMetadataDisplay
    @Published private(set) var maxTagCount: Int

    private init() {
        display = RankMetadataDisplay(
            rawValue: UserDefaults.standard.string(forKey: Self.displayKey) ?? ""
        ) ?? .categories
        if UserDefaults.standard.object(forKey: Self.tagCountKey) == nil {
            maxTagCount = 3
        } else {
            maxTagCount = min(max(UserDefaults.standard.integer(forKey: Self.tagCountKey), 1), 5)
        }
    }

    func setDisplay(_ display: RankMetadataDisplay) {
        self.display = display
        UserDefaults.standard.set(display.rawValue, forKey: Self.displayKey)
    }

    func setMaxTagCount(_ count: Int) {
        let clamped = min(max(count, 1), 5)
        maxTagCount = clamped
        UserDefaults.standard.set(clamped, forKey: Self.tagCountKey)
    }
}
