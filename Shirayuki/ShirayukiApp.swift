import SwiftUI

/// Application entry point that installs shared state and appearance dependencies.
@main
struct ShirayukiApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var localization = AppLocalization.shared
    @StateObject private var navigation = AppNavigationCoordinator.shared
    @StateObject private var agentUIState = AgentUIState.shared
    @AppStorage("app_theme_mode") private var appThemeMode = AppThemeMode.system.rawValue
    
    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(appState)
                .environmentObject(localization)
                .environmentObject(navigation)
                .environmentObject(agentUIState)
                .environment(\.locale, localization.locale)
                .preferredColorScheme(AppThemeMode(rawValue: appThemeMode)?.colorScheme)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-agent-surfaces") {
            AgentUITestSurfaceHost()
        } else {
            MainTabView()
        }
        #else
        MainTabView()
        #endif
    }
}
