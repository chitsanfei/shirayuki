import Foundation

enum ShirayukiTab: String, CaseIterable, Hashable {
    case home
    case categories
    case games
    case profile
    case search

    var title: String {
        switch self {
        case .home: return "首页"
        case .categories: return "分类"
        case .games: return "游戏中心"
        case .profile: return "我的"
        case .search: return "搜索"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .categories: return "square.grid.2x2.fill"
        case .games: return "gamecontroller.fill"
        case .profile: return "person.crop.circle.fill"
        case .search: return "magnifyingglass.circle.fill"
        }
    }

    var path: String {
        switch self {
        case .home: return "/"
        case .categories: return "/categories"
        case .games: return "/games"
        case .profile: return "/profile"
        case .search: return "/comics/search"
        }
    }
}
