import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case categories
    case search
    case profile
    
    var id: String { rawValue }
    
    var title: String {
        AppLocalization.text(titleKey)
    }

    private var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .categories: return "tab.categories"
        case .search: return "tab.search"
        case .profile: return "tab.profile"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .categories: return "square.grid.2x2"
        case .search: return "magnifyingglass"
        case .profile: return "person"
        }
    }
}
