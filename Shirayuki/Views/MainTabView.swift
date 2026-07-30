import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: AppTab = .home
    
    var body: some View {
        ZStack {
            if appState.isRestoringSession {
                RestoringSessionView()
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if appState.isLoggedIn {
                authenticatedTabs
                    .transition(.sessionScreen)
            } else {
                LoginView()
                    .transition(.sessionScreen)
            }
        }
        .animation(.sessionSpring, value: appState.isRestoringSession)
        .animation(.sessionSpring, value: appState.isLoggedIn)
        .ignoresSafeArea(.keyboard)
    }

    private var authenticatedTabs: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(AppTab.home.title, systemImage: AppTab.home.icon)
                }
                .tag(AppTab.home)
            CategoriesView()
                .tabItem {
                    Label(AppTab.categories.title, systemImage: AppTab.categories.icon)
                }
                .tag(AppTab.categories)
            SearchView()
                .tabItem {
                    Label(AppTab.search.title, systemImage: AppTab.search.icon)
                }
                .tag(AppTab.search)
            ProfileView()
                .tabItem {
                    Label(AppTab.profile.title, systemImage: AppTab.profile.icon)
                }
                .tag(AppTab.profile)
        }
    }
}

private extension AnyTransition {
    static let sessionScreen = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.92, anchor: .center)
            .combined(with: .move(edge: .trailing)),
        removal: .scale(scale: 1.06, anchor: .center)
            .combined(with: .move(edge: .leading))
    )
}

private extension Animation {
    static let sessionSpring = Animation.interpolatingSpring(
        mass: 1,
        stiffness: 170,
        damping: 21,
        initialVelocity: 0.32
    )
}

private struct RestoringSessionView: View {
    @ObservedObject private var localization = AppLocalization.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.22),
                    backgroundColor
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                AppBrandIcon(size: 88, cornerRadius: 24)
                ProgressView()
                Text(localization.text("auth.restoring.title"))
                    .font(.system(size: 20, weight: .bold))
                Text(localization.text("auth.restoring.subtitle"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(28)
        }
    }

    private var backgroundColor: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.white
        #endif
    }
}
