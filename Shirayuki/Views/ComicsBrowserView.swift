import Combine
import SwiftUI

enum ComicsBrowserSource: Hashable, Identifiable, Sendable {
    case category(String)
    case favorites
    
    var id: String {
        switch self {
        case .category(let name):
            return "category:\(name)"
        case .favorites:
            return "favorites"
        }
    }
    
    var title: String {
        switch self {
        case .category(let name):
            return name
        case .favorites:
            return AppLocalization.text("browser.favorites.title")
        }
    }
    
    var emptyTitle: String {
        switch self {
        case .category:
            return AppLocalization.text("browser.empty.comics")
        case .favorites:
            return AppLocalization.text("browser.empty.favorites")
        }
    }
    
    var emptySubtitle: String {
        switch self {
        case .category(let name):
            return AppLocalization.text("browser.empty.category.subtitle", name)
        case .favorites:
            return AppLocalization.text("browser.empty.favorites.subtitle")
        }
    }
}

@MainActor
final class ComicsBrowserViewModel: ObservableObject {
    @Published var comics: [ComicDoc] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var totalPages = 1
    
    let source: ComicsBrowserSource
    
    init(source: ComicsBrowserSource) {
        self.source = source
    }
    
    func load(reset: Bool = false) async {
        if reset {
            currentPage = 1
            comics = []
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result: ComicsList
            switch source {
            case .category(let category):
                result = try await PicaAPIService.shared.fetchComics(
                    payload: ComicsPayload(
                        page: currentPage,
                        c: category,
                        s: .dd,
                        t: nil,
                        a: nil,
                        ct: nil,
                        ca: nil
                    )
                )
            case .favorites:
                result = try await PicaAPIService.shared.fetchFavoriteComics(page: currentPage, sort: .dd)
            }
            
            if reset {
                comics = result.docs
            } else {
                comics.append(contentsOf: result.docs)
            }
            
            currentPage = result.page
            totalPages = result.pages
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadNextPageIfNeeded(current comic: ComicDoc) async {
        guard comic.id == comics.last?.id else { return }
        guard !isLoading, currentPage < totalPages else { return }
        currentPage += 1
        await load()
    }
}

struct ComicsBrowserView: View {
    let source: ComicsBrowserSource
    
    @StateObject private var viewModel: ComicsBrowserViewModel
    @ObservedObject private var localization = AppLocalization.shared
    @State private var selectedComicId: String?
    
    init(source: ComicsBrowserSource) {
        self.source = source
        _viewModel = StateObject(wrappedValue: ComicsBrowserViewModel(source: source))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let errorMessage = viewModel.errorMessage, viewModel.comics.isEmpty, !viewModel.isLoading {
                    contentErrorState(message: errorMessage)
                } else if viewModel.comics.isEmpty, viewModel.isLoading {
                    ComicSelectionGridSkeleton()
                } else if viewModel.comics.isEmpty {
                    contentEmptyState
                } else {
                    ComicSelectionGrid(viewModel.comics, id: \.id) { comic in
                        ComicCard(comic: comic)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedComicId = comic.id
                            }
                            .onAppear {
                                Task {
                                    await viewModel.loadNextPageIfNeeded(current: comic)
                                }
                            }
                    }
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
        .navigationDestination(item: $selectedComicId) { comicId in
            ComicDetailView(comicId: comicId)
        }
        .refreshable {
            await viewModel.load(reset: true)
        }
        .task {
            guard viewModel.comics.isEmpty else { return }
            await viewModel.load(reset: true)
        }
    }
    
    private var contentEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: source == .favorites ? "heart.slash" : "book.closed")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.45))
            Text(source.emptyTitle)
                .font(.system(size: 18, weight: .semibold))
            Text(source.emptySubtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
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
                Task {
                    await viewModel.load(reset: true)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}
