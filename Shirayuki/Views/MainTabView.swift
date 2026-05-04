import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState.shared
    @State private var selectedTab: AppTab = .home
    
    var body: some View {
        Group {
            if appState.isRestoringSession {
                RestoringSessionView()
            } else if appState.isLoggedIn {
                authenticatedTabs
            } else {
                LoginView()
            }
        }
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
