import Combine
import SwiftUI

/// Data source represented by the shared paginated comic browser.
enum ComicsBrowserSource: Hashable, Identifiable, Sendable {
    case category(String)
    case author(String)
    case chineseTeam(String)
    case favorites
    
    var id: String {
        switch self {
        case .category(let name):
            return "category:\(name)"
        case .author(let name):
            return "author:\(name)"
        case .chineseTeam(let name):
            return "chineseTeam:\(name)"
        case .favorites:
            return "favorites"
        }
    }
    
    var title: String {
        switch self {
        case .category(let name), .author(let name), .chineseTeam(let name):
            return name
        case .favorites:
            return AppLocalization.text("browser.favorites.title")
        }
    }
    
    var emptyTitle: String {
        switch self {
        case .category, .author, .chineseTeam:
            return AppLocalization.text("browser.empty.comics")
        case .favorites:
            return AppLocalization.text("browser.empty.favorites")
        }
    }
    
    var emptySubtitle: String {
        switch self {
        case .category(let name):
            return AppLocalization.text("browser.empty.category.subtitle", name)
        case .author(let name), .chineseTeam(let name):
            return AppLocalization.text("browser.empty.creator.subtitle", name)
        case .favorites:
            return AppLocalization.text("browser.empty.favorites.subtitle")
        }
    }

    /// Favorites only honor date ordering; comic-list sources accept every sort code.
    var supportedSorts: [ComicSortType] {
        switch self {
        case .category, .author, .chineseTeam:
            return ComicSortType.allCases
        case .favorites:
            return [.dd, .da]
        }
    }
}

/// Loads and paginates comics for a configured browser source.
@MainActor
final class ComicsBrowserViewModel: ObservableViewModel {
    @Published var comics: [ComicSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published private(set) var lastLoadedPageIDs: [String] = []
    @Published private(set) var lastEvaluatedBlockedRevision: UInt64 = 0
    @Published private(set) var sort: ComicSortType = .dd
    
    let source: ComicsBrowserSource
    /// Bumped per request so a refresh discards any page response still in flight.
    private var loadGeneration = 0
    
    init(source: ComicsBrowserSource) {
        self.source = source
    }
    
    /// Loads page 1 when resetting, otherwise the page after `currentPage`.
    /// `currentPage` only advances once that page has loaded successfully.
    func load(reset: Bool = false) async {
        if reset {
            currentPage = 1
            comics = []
        }
        let page = reset ? 1 : currentPage + 1
        
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if generation == loadGeneration { isLoading = false }
        }
        
        do {
            let result = try await fetch(page: page)
            guard generation == loadGeneration else { return }
            
            if reset {
                comics = result.docs
            } else {
                comics.append(contentsOf: result.docs)
            }
            lastLoadedPageIDs = result.docs.map(\.id)
            
            currentPage = result.page
            totalPages = result.pages
        } catch {
            guard generation == loadGeneration else { return }
            handleError(error)
        }
    }

    /// Switches the server-side ordering and reloads from page 1.
    func setSort(_ newSort: ComicSortType) async {
        guard newSort != sort, source.supportedSorts.contains(newSort) else { return }
        sort = newSort
        await load(reset: true)
    }

    func loadNextPage() async {
        guard !isLoading, currentPage < totalPages else { return }
        await load()
    }

    /// True when a later page failed while earlier results are still on screen.
    var nextPageFailed: Bool {
        errorMessage != nil && !isLoading && !comics.isEmpty
    }

    private func fetch(page: Int) async throws -> ComicsList {
        let api = PicaAPIService.shared
        switch source {
        case .category(let category):
            return try await api.fetchComics(
                payload: ComicsPayload(page: page, c: category, s: sort, t: nil, a: nil, ct: nil, ca: nil)
            )
        case .author(let author):
            return try await api.fetchComics(
                payload: ComicsPayload(page: page, c: nil, s: sort, t: nil, a: author, ct: nil, ca: nil)
            )
        case .chineseTeam(let team):
            return try await api.fetchComics(
                payload: ComicsPayload(page: page, c: nil, s: sort, t: nil, a: nil, ct: team, ca: nil)
            )
        case .favorites:
            return try await api.fetchFavoriteComics(page: page, sort: sort)
        }
    }

    func visibleComics(for snapshot: BlockedWordSnapshot) -> [ComicSummary] {
        PicaAgentAdapters.visibleComics(comics, snapshot: snapshot)
    }

    func shouldLoadFilteredPage(for snapshot: BlockedWordSnapshot) -> Bool {
        guard !isLoading, errorMessage == nil, currentPage < totalPages else { return false }
        let latestIDs = Set(lastLoadedPageIDs)
        let latest = comics.filter { latestIDs.contains($0.id) }
        return !latest.isEmpty && PicaAgentAdapters.visibleComics(latest, snapshot: snapshot).isEmpty
    }

    func resultsHiddenAtTerminal(for snapshot: BlockedWordSnapshot) -> Bool {
        !comics.isEmpty && currentPage >= totalPages && visibleComics(for: snapshot).isEmpty
    }

    func recordBlockedRevision(_ revision: UInt64) {
        lastEvaluatedBlockedRevision = revision
    }
}

/// Shared list screen for categories, creators, and account favorites.
struct ComicsBrowserView: View {
    let source: ComicsBrowserSource

    @StateObject private var viewModel: ComicsBrowserViewModel
    @ObservedObject private var localization = AppLocalization.shared
    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @EnvironmentObject private var blockedWords: UserDefaultsBlockedWordRepository
    @EnvironmentObject private var agentPageContent: AgentPageContentStore
    @State private var pageContentOwnerID = UUID()
    @State private var selectedComicId: String?

    init(source: ComicsBrowserSource) {
        self.source = source
        _viewModel = StateObject(wrappedValue: ComicsBrowserViewModel(source: source))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let errorMessage = viewModel.errorMessage, visibleComics.isEmpty, !viewModel.isLoading {
                    contentErrorState(message: errorMessage)
                } else if viewModel.comics.isEmpty, viewModel.isLoading {
                    ComicSelectionGridSkeleton()
                } else if visibleComics.isEmpty {
                    contentEmptyState(
                        hiddenByFilter: viewModel.resultsHiddenAtTerminal(for: blockedWords.currentSnapshot)
                    )
                } else {
                    ComicSelectionGrid(visibleComics, id: \.id) { comic in
                        ComicCard(comic: comic)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedComicId = comic.id }
                            .onAppear {
                                guard comic.id == visibleComics.last?.id else { return }
                                Task { await viewModel.loadNextPage() }
                            }
                    }
                }

                if viewModel.nextPageFailed, !visibleComics.isEmpty, let errorMessage = viewModel.errorMessage {
                    nextPageErrorState(message: errorMessage)
                } else if viewModel.shouldLoadFilteredPage(for: blockedWords.currentSnapshot) {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .onAppear { Task { await viewModel.loadNextPage() } }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .navigationTitle(source.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                sortMenu
            }
        }
        .navigationDestination(item: $selectedComicId) { comicId in
            ComicDetailView(comicId: comicId)
        }
        .refreshable { await viewModel.load(reset: true) }
        .task {
            guard viewModel.comics.isEmpty else { return }
            await viewModel.load(reset: true)
        }
        .agentPageContext(.tab("browser:\(source.id)"))
        .onAppear {
            publishAgentPageContent()
        }
        .onChange(of: navigation.pendingComicID) { _, _ in
            guard navigation.currentContext == .tab("browser:\(source.id)"),
                  let comicID = navigation.consumePendingComic() else { return }
            selectedComicId = comicID
        }
        .onChange(of: blockedWords.currentSnapshot.revision) { _, revision in
            viewModel.recordBlockedRevision(revision)
            publishAgentPageContent()
        }
        .onChange(of: viewModel.comics.map(\.id)) { _, _ in
            publishAgentPageContent()
        }
        .onDisappear {
            agentPageContent.clear(ownerID: pageContentOwnerID)
        }
    }

    private func publishAgentPageContent() {
        let sourceName = switch source {
        case let .category(name): "category.\(name)"
        case let .author(name): "author.\(name)"
        case let .chineseTeam(name): "chineseTeam.\(name)"
        case .favorites: "favorites"
        }
        agentPageContent.publish(
            PicaAgentAdapters.pageContent(
                source: sourceName,
                title: source.title,
                comics: visibleComics,
                itemLimit: AgentPageContentSnapshot.maximumComicItems
            ),
            ownerID: pageContentOwnerID
        )
    }

    private var sortMenu: some View {
        Menu {
            Picker(
                localization.text("search.filter.sort"),
                selection: Binding(
                    get: { viewModel.sort },
                    set: { newSort in Task { await viewModel.setSort(newSort) } }
                )
            ) {
                ForEach(source.supportedSorts) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel(localization.text("search.filter.sort"))
        .accessibilityIdentifier("browserSortMenu")
    }

    private var visibleComics: [ComicSummary] {
        viewModel.visibleComics(for: blockedWords.currentSnapshot)
    }

    private func contentEmptyState(hiddenByFilter: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: source == .favorites ? "heart.slash" : "book.closed")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.45))
            Text(hiddenByFilter ? localization.text("contentFilter.resultsHidden") : source.emptyTitle)
                .font(.system(size: 18, weight: .semibold))
            if !hiddenByFilter {
                Text(source.emptySubtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func nextPageErrorState(message: String) -> some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(localization.text("common.reload")) {
                Task { await viewModel.loadNextPage() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    private func contentErrorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(localization.text("common.reload")) {
                Task { await viewModel.load(reset: true) }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}
