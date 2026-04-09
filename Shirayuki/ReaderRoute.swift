import Foundation

enum ReaderStatus: Equatable {
    case notLoggedIn
    case loggedIn
    case inReader

    var text: String {
        switch self {
        case .notLoggedIn: return "未登录"
        case .loggedIn: return "已登陆"
        case .inReader: return "已进入阅读器"
        }
    }

}

enum ReaderRoute {
    static func normalized(_ path: String) -> String {
        let lower = path.lowercased()
        return lower.isEmpty ? "/" : lower
    }

    static func isReaderPath(_ path: String) -> Bool {
        normalized(path).contains("/comic/reader/")
    }

    static func tab(for path: String) -> ShirayukiTab? {
        let normalizedPath = normalized(path)
        if normalizedPath == "/" { return .home }
        if normalizedPath.hasPrefix("/categories") { return .categories }
        if normalizedPath.hasPrefix("/games") { return .games }
        if normalizedPath.hasPrefix("/profile") { return .profile }
        if normalizedPath.hasPrefix("/comics/search") { return .search }
        return nil
    }

    static func status(isLoggedIn: Bool, isInReader: Bool) -> ReaderStatus {
        if isInReader { return .inReader }
        return isLoggedIn ? .loggedIn : .notLoggedIn
    }
}
