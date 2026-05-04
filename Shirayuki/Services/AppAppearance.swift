import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        AppLocalization.text(titleKey)
    }

    private var titleKey: String {
        switch self {
        case .system: return "theme.system"
        case .light: return "theme.light"
        case .dark: return "theme.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
