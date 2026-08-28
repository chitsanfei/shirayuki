import SwiftUI

/// Switches between authentication, restoration, and the primary tab hierarchy.
struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @State private var selectedTab: AppTab = .home
    
    var body: some View {
        AgentOverlayHost(context: rootContext, isRoot: true) {
            ZStack {
                switch appState.startupState {
                case .loading(let phase):
                    StartupStatusView(phase: phase)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                case .readyAuthenticated:
                    authenticatedTabs
                        .transition(.sessionScreen)
                case .readyUnauthenticated:
                    LoginView()
                        .transition(.sessionScreen)
                case .failed(let message):
                    StartupFailureView(
                        message: message,
                        retry: appState.retryStartup,
                        login: appState.logout
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.sessionSpring, value: appState.startupState)
            .ignoresSafeArea(.keyboard)
            .onChange(of: navigation.pendingComicID) { _, comicID in
                guard comicID != nil else { return }
                switch navigation.currentContext {
                case .detail:
                    break
                case .tab(let value) where value == AppTab.home.rawValue
                    || value == AppTab.search.rawValue || value.hasPrefix("browser:"):
                    break
                default:
                    selectedTab = .home
                }
            }
            .onChange(of: navigation.pendingReaderRequest) { _, request in
                guard let request else { return }
                if case .detail(let comicID) = navigation.currentContext,
                   comicID == request.comicID {
                    return
                }
                selectedTab = .home
            }
            .onChange(of: selectedTab) { _, tab in
                navigation.setSelectedTab(tab.rawValue)
                if case .readyAuthenticated = appState.startupState {
                    navigation.setRootContext(.tab(tab.rawValue))
                }
            }
            .onChange(of: appState.startupState) { _, _ in
                navigation.setRootContext(rootContext)
            }
            .onAppear {
                navigation.setRootContext(rootContext)
                if case .tab(let tab) = rootContext {
                    navigation.setSelectedTab(tab)
                }
            }
        }
    }

    private var rootContext: AgentPageContext {
        switch appState.startupState {
        case .loading(let phase): return .startup(phase)
        case .failed: return .failed
        case .readyUnauthenticated: return .login
        case .readyAuthenticated: return .tab(selectedTab.rawValue)
        }
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
            .combined(with: .move(edge: .bottom)),
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

private struct StartupStatusView: View {
    let phase: StartupLoadingPhase

    var body: some View {
        ZStack {
            startupBackground
            VStack(spacing: 18) {
                AppBrandIcon(size: 88, cornerRadius: 24)
                ProgressView()
                Text(AppLocalization.text(localizationKey))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(28)
        }
    }

    private var localizationKey: String {
        switch phase {
        case .preparing: return "startup.preparing"
        case .validatingSession: return "startup.validatingSession"
        case .restoringCredentials: return "startup.restoringCredentials"
        case .loadingProfile: return "startup.loadingProfile"
        }
    }
}

private struct StartupFailureView: View {
    let message: String
    let retry: () -> Void
    let login: () -> Void

    var body: some View {
        ZStack {
            startupBackground
            VStack(spacing: 16) {
                AppBrandIcon(size: 88, cornerRadius: 24)
                Text(AppLocalization.text("startup.failed"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                Text(message.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack {
                    Button(AppLocalization.text("startup.login"), action: login)
                        .buttonStyle(.bordered)
                    Button(AppLocalization.text("startup.retry"), action: retry)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(28)
        }
    }
}

private var startupBackground: some View {
    LinearGradient(
        colors: [Color.accentColor.opacity(0.22), startupBackgroundColor],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
}

private var startupBackgroundColor: Color {
    #if canImport(UIKit)
    Color(uiColor: .systemBackground)
    #elseif canImport(AppKit)
    Color(nsColor: .windowBackgroundColor)
    #else
    Color.white
    #endif
}

#if DEBUG
@MainActor
struct AgentUITestSurfaceHost: View {
    private enum PresentedSurface: String, Identifiable {
        case searchFilters
        case downloadOptions
        case offlineDownload

        var id: String { rawValue }
    }

    @StateObject private var searchViewModel: SearchViewModel
    @StateObject private var readerViewModel: ReaderViewModel
    @State private var presentedSurface: PresentedSurface?
    @State private var isReaderPresented = false

    init() {
        let record = Self.fixtureRecord
        let chapter = PicaChapter(uid: "fixture-chapter", title: "Fixture Chapter", order: 1, id: "fixture-chapter")
        let reader = ReaderViewModel(
            comic: ComicDetail(offlineRecord: record),
            initialChapters: [chapter],
            initialChapterId: chapter.id,
            offlineOnly: true
        )
        reader.images = [
            ChapterImage(uid: "fixture-image", id: "fixture-image", offlineURL: "fixture://image")
        ]
        reader.currentChapterTitle = chapter.title
        reader.showToolbar = true
        _searchViewModel = StateObject(wrappedValue: SearchViewModel())
        _readerViewModel = StateObject(wrappedValue: reader)
    }

    var body: some View {
        AgentOverlayHost(context: .tab("ui-test"), isRoot: true) {
            NavigationStack {
                VStack(spacing: 14) {
                    Text("Agent surface fixture")
                        .font(.headline)

                    Button("Search filters") {
                        presentedSurface = .searchFilters
                    }
                    .accessibilityIdentifier("searchFiltersButton")

                    Button("Download options") {
                        presentedSurface = .downloadOptions
                    }
                    .accessibilityIdentifier("downloadOptionsButton")

                    Button("Offline download") {
                        presentedSurface = .offlineDownload
                    }
                    .accessibilityIdentifier("offlineDownloadButton")

                    Button("Reader") {
                        isReaderPresented = true
                    }
                    .accessibilityIdentifier("readerFixtureButton")
                }
                .padding(24)
            }
            .sheet(item: $presentedSurface) { surface in
                switch surface {
                case .searchFilters:
                    SearchFiltersSheet(viewModel: searchViewModel)
                        .agentSurfaceHost(
                            context: .nonSettingsSheet(parent: .tab("ui-test"), kind: surface.rawValue)
                        )
                case .downloadOptions:
                    DownloadOptionsSheet(
                        chapters: Self.fixtureChapters,
                        downloadedChapterIDs: []
                    ) { _, _ in }
                    .agentSurfaceHost(
                        context: .nonSettingsSheet(parent: .tab("ui-test"), kind: surface.rawValue)
                    )
                case .offlineDownload:
                    OfflineDownloadSheet(record: Self.fixtureRecord) { _ in }
                        .agentSurfaceHost(
                            context: .nonSettingsSheet(parent: .tab("ui-test"), kind: surface.rawValue)
                        )
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $isReaderPresented) {
                ReaderView(viewModel: readerViewModel)
            }
            #else
            .sheet(isPresented: $isReaderPresented) {
                ReaderView(viewModel: readerViewModel)
            }
            #endif
        }
    }

    private static let fixtureChapters = [
        PicaChapter(uid: "fixture-chapter", title: "Fixture Chapter", order: 1, id: "fixture-chapter")
    ]

    private static let fixtureRecord = OfflineComicRecord(
        id: "ui-test-comic",
        title: "Agent UI Fixture",
        thumbURL: "",
        createdAt: "",
        updatedAt: "",
        downloadedAt: Date(timeIntervalSince1970: 0),
        quality: .high,
        chapters: [
            OfflineChapterRecord(
                id: "fixture-chapter",
                title: "Fixture Chapter",
                order: 1,
                quality: .high,
                images: []
            )
        ]
    )
}
#endif
