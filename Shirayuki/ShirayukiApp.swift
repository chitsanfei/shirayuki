import SwiftUI

@main
struct ShirayukiApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var localization = AppLocalization.shared
    @AppStorage("app_theme_mode") private var appThemeMode = AppThemeMode.system.rawValue
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .environmentObject(localization)
                .environment(\.locale, localization.locale)
                .preferredColorScheme(AppThemeMode(rawValue: appThemeMode)?.colorScheme)
        }
    }
}
