import SwiftUI

/// Presents discovery feeds, rankings, and category entry points.
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject private var rankDisplay = AppRankDisplayStore.shared
    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @EnvironmentObject private var blockedWords: UserDefaultsBlockedWordRepository
    @EnvironmentObject private var agentPageContent: AgentPageContentStore
    @State private var pageContentOwnerID = UUID()
    @State private var selectedComicId: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    modeFilterSection
                    comicsSection
                }
                .padding(.vertical, 16)
                .padding(.bottom, 120)
            }
            .navigationTitle(localization.text("home.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await viewModel.refresh()
            }
            .navigationDestination(item: $selectedComicId) { comicId in
                ComicDetailView(comicId: comicId)
            }
            .task {
                guard viewModel.comics.isEmpty else { return }
                await viewModel.loadHome()
            }
        }
        .agentPageContext(.tab(AppTab.home.rawValue))
        .onAppear {
            routePendingReader()
            consumeAgentComicRoute()
            publishAgentPageContent()
        }
        .onChange(of: navigation.pendingComicID) { _, _ in
            consumeAgentComicRoute()
        }
        .onChange(of: navigation.pendingReaderRequest) { _, _ in
            routePendingReader()
        }
        .onChange(of: navigation.currentContext) { _, context in
            if context == .tab(AppTab.home.rawValue) {
                routePendingReader()
                consumeAgentComicRoute()
            }
        }
        .onChange(of: blockedWords.currentSnapshot.revision) { _, revision in
            viewModel.recordBlockedRevision(revision)
            publishAgentPageContent()
        }
        .onChange(of: viewModel.comics.map(\.id)) { _, _ in
            publishAgentPageContent()
        }
        .onChange(of: viewModel.selectedMode) { _, _ in
            publishAgentPageContent()
        }
        .onDisappear {
            agentPageContent.clear(ownerID: pageContentOwnerID)
        }
    }

    private func publishAgentPageContent() {
        let visible = viewModel.visibleComics(for: blockedWords.currentSnapshot)
        agentPageContent.publish(
            PicaAgentAdapters.pageContent(
                source: "home.\(viewModel.selectedMode.rawValue)",
                title: viewModel.navigationTitle,
                comics: visible,
                itemLimit: AgentPageContentSnapshot.maximumComicItems
            ),
            ownerID: pageContentOwnerID
        )
    }

    private func routePendingReader() {
        guard let request = navigation.pendingReaderRequest else { return }
        selectedComicId = request.comicID
    }

    private func consumeAgentComicRoute() {
        guard navigation.currentContext == .tab(AppTab.home.rawValue),
              let comicID = navigation.consumePendingComic() else { return }
        selectedComicId = comicID
    }

    private var modeFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(HomeDisplayMode.allCases) { mode in
                    CategoryChip(
                        title: mode.displayName,
                        systemImage: mode.systemImage,
                        isSelected: viewModel.selectedMode == mode
                    ) {
                        Task {
                            await viewModel.selectMode(mode)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var comicsSection: some View {
        let snapshot = blockedWords.currentSnapshot
        let visibleComics = viewModel.visibleComics(for: snapshot)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.navigationTitle)
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                if viewModel.isLoading, !visibleComics.isEmpty {
                    ProgressView()
                }
            }
            .padding(.horizontal, 16)

            if let errorMessage = viewModel.errorMessage, visibleComics.isEmpty, !viewModel.isLoading {
                contentErrorState(message: errorMessage)
            } else if viewModel.comics.isEmpty, viewModel.isLoading {
                ComicSelectionGridSkeleton()
                    .padding(.horizontal, 16)
            } else if visibleComics.isEmpty {
                emptyState(hiddenByFilter: viewModel.resultsHiddenAtTerminal(for: snapshot))
            } else {
                ComicSelectionGrid(visibleComics, id: \.id) { comic in
                    Group {
                        if viewModel.selectedMode == .latest {
                            ComicCard(comic: comic)
                        } else {
                            RankComicCard(
                                comic: comic,
                                metadataDisplay: rankDisplay.display,
                                maxTagCount: rankDisplay.maxTagCount
                            )
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedComicId = comic.id
                    }
                    .onAppear {
                        guard comic.id == visibleComics.last?.id else { return }
                        Task { await viewModel.loadNextPage() }
                    }
                }
                .padding(.horizontal, 16)
            }

            if viewModel.shouldLoadFilteredPage(for: snapshot) {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear { Task { await viewModel.loadNextPage() } }
            }
        }
    }

    private func emptyState(hiddenByFilter: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.45))
            Text(localization.text(hiddenByFilter ? "contentFilter.resultsHidden" : "home.empty.title"))
                .font(.system(size: 18, weight: .semibold))
            if !hiddenByFilter {
                Text(localization.text("home.empty.subtitle"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(.horizontal, 16)
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
                    await viewModel.loadComics(reset: true)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(.horizontal, 16)
    }
}

/// Selectable category filter used by the home screen.
struct CategoryChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
