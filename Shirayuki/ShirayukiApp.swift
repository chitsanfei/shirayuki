import SwiftUI

/// Application entry point and sole composition root.
@main
struct ShirayukiApp: App {
    @StateObject private var appState: AppState
    @StateObject private var localization: AppLocalization
    @StateObject private var navigation: AppNavigationCoordinator
    @StateObject private var agentUIState: AgentUIState
    @StateObject private var appearance: AppAppearanceStore
    @StateObject private var blockedWords: UserDefaultsBlockedWordRepository
    @StateObject private var agentPageContent: AgentPageContentStore
    @StateObject private var agentRuntime: AgentRuntime

    init() {
        let appState = AppState.shared
        let localization = AppLocalization.shared
        let navigation = AppNavigationCoordinator.shared
        let agentUIState = AgentUIState.shared
        let appearance = AppAppearanceStore()
        let blockedWords = UserDefaultsBlockedWordRepository()
        let agentPageContent = AgentPageContentStore()
        let llmSettings = LLMSettingsStore.shared
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-agent-unconfigured") {
            llmSettings.resetToDefaults()
            llmSettings.clearAPIKey()
        } else if ProcessInfo.processInfo.arguments.contains("--ui-test-agent-failing-provider") {
            _ = llmSettings.apply(
                provider: .openAICompatible,
                model: "deepseek-chat",
                baseURL: "https://127.0.0.1:1",
                apiKey: "ui-test-api-key",
                privacyConfirmed: true
            )
        } else if ProcessInfo.processInfo.arguments.contains("--ui-test-agent-configured-key") {
            llmSettings.resetToDefaults()
            _ = llmSettings.apply(
                provider: .openAICompatible,
                model: LLMSettingsStore.defaultModel,
                baseURL: LLMSettingsStore.defaultEndpoint.absoluteString,
                apiKey: "ui-test-api-key"
            )
        }
        #endif
        let sessions = FileAgentSessionRepository()
        let commands = AgentCommandService(
            navigation: navigation,
            blockedWords: blockedWords,
            pageContent: agentPageContent,
            sessionIsLoggedIn: { appState.isLoggedIn },
            llmConfiguration: { llmSettings.configuration },
            llmHasAPIKey: { llmSettings.hasAPIKey },
            riskAuthorizationEnabled: { llmSettings.riskAuthorizationEnabled }
        )
        let runtime = AgentRuntime(
            sessions: sessions,
            commands: commands,
            appState: appState,
            llmSettings: llmSettings
        )

        _appState = StateObject(wrappedValue: appState)
        _localization = StateObject(wrappedValue: localization)
        _navigation = StateObject(wrappedValue: navigation)
        _agentUIState = StateObject(wrappedValue: agentUIState)
        _appearance = StateObject(wrappedValue: appearance)
        _blockedWords = StateObject(wrappedValue: blockedWords)
        _agentRuntime = StateObject(wrappedValue: runtime)
        _agentPageContent = StateObject(wrappedValue: agentPageContent)
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(appState)
                .environmentObject(localization)
                .environmentObject(navigation)
                .environmentObject(agentUIState)
                .environmentObject(appearance)
                .environmentObject(blockedWords)
                .environmentObject(agentRuntime)
                .environmentObject(agentPageContent)
                .environment(\.locale, localization.locale)
                .preferredColorScheme(appearance.themeMode.colorScheme)
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
