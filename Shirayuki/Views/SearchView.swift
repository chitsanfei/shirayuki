import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject private var localization = AppLocalization.shared
    @State private var selectedComicId: String?
    @State private var showFilters = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    searchBar
                    
                    if viewModel.query.isEmpty {
                        if !viewModel.searchHistory.isEmpty {
                            historySection
                        }
                        
                        suggestionsSection
                    } else {
                        resultsSection
                    }
                }
                .padding(.vertical, 12)
                .padding(.bottom, 120)
            }
            .navigationTitle(localization.text("search.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .navigationDestination(item: $selectedComicId) { comicId in
                ComicDetailView(comicId: comicId)
            }
            .sheet(isPresented: $showFilters) {
                SearchFiltersSheet(viewModel: viewModel)
            }
            .task {
                guard viewModel.hotKeywords.isEmpty else { return }
                await viewModel.loadHotKeywords()
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                TextField(localization.text("search.placeholder"), text: $viewModel.query)
                    .font(.system(size: 18, weight: .medium))
                    .submitLabel(.search)
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                    .onSubmit {
                        Task {
                            await viewModel.search(reset: true)
                        }
                    }
                
                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.clearQuery()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            
            Button {
                showFilters = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localization.text("search.history"))
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Button(localization.text("common.clear")) {
                    viewModel.clearHistory()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            FlowLayout(spacing: 8) {
                ForEach(viewModel.searchHistory, id: \.self) { history in
                    SearchKeywordChip(title: history) {
                        viewModel.query = history
                        Task {
                            await viewModel.search(reset: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.text("search.hot"))
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal, 16)
            
            if viewModel.hotKeywords.isEmpty && viewModel.isLoading {
                ProgressView()
                    .padding(.horizontal, 16)
            } else if viewModel.hotKeywords.isEmpty {
                Text(localization.text("search.noSuggestions"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        SearchKeywordChip(title: suggestion, emphasized: true) {
                            viewModel.query = suggestion
                            Task {
                                await viewModel.search(reset: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localization.text("search.results"))
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                if viewModel.isLoading, !viewModel.comics.isEmpty {
                    ProgressView()
                }
            }
            .padding(.horizontal, 16)
            
            if let errorMessage = viewModel.errorMessage, viewModel.comics.isEmpty, !viewModel.isLoading {
                contentErrorState(message: errorMessage)
            } else if viewModel.comics.isEmpty, viewModel.isLoading {
                ComicSelectionGridSkeleton()
                    .padding(.horizontal, 16)
            } else if viewModel.comics.isEmpty {
                emptyState
            } else {
                ComicSelectionGrid(viewModel.comics, id: \.id) { comic in
                    SearchComicCard(comic: comic)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedComicId = comic.id
                        }
                        .onAppear {
                            guard comic.id == viewModel.comics.last?.id else { return }
                            Task {
                                await viewModel.loadNextPage()
                            }
                        }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.45))
            Text(localization.text("search.empty.title"))
                .font(.system(size: 18, weight: .semibold))
            Text(localization.text("search.empty.subtitle"))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(.horizontal, 16)
    }
    
    private func contentErrorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(localization.text("search.retry")) {
                Task {
                    await viewModel.search(reset: true)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(.horizontal, 16)
    }
}

struct SearchKeywordChip: View {
    let title: String
    var emphasized = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(emphasized ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(emphasized ? Color.accentColor.opacity(0.24) : Color.white.opacity(0.05), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SearchFiltersSheet: View {
    @ObservedObject var viewModel: SearchViewModel
    @ObservedObject private var localization = AppLocalization.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(localization.text("search.filter.sort")) {
                    Picker(localization.text("search.filter.mode"), selection: $viewModel.sortMode) {
                        ForEach(ComicSortType.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    
                    Picker(localization.text("search.filter.direction"), selection: $viewModel.sortAscending) {
                        Text(localization.text("search.filter.ascending")).tag(true)
                        Text(localization.text("search.filter.descending")).tag(false)
                    }
                }
            }
            .navigationTitle(localization.text("search.filter.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text("common.apply")) {
                        Task { await viewModel.search(reset: true) }
                        dismiss()
                    }
                }
            }
        }
    }
}
