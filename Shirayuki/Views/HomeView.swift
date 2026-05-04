import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var localization = AppLocalization.shared
    @State private var selectedComicId: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    categoriesSection
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
                guard viewModel.categories.isEmpty, viewModel.comics.isEmpty else { return }
                await viewModel.loadHome()
            }
        }
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localization.text("home.categories"))
                .font(.system(size: 28, weight: .bold))
                .padding(.horizontal, 16)
            
            if !viewModel.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CategoryChip(
                            title: localization.text("home.all"),
                            imageURL: nil,
                            isSelected: viewModel.selectedCategory == nil
                        ) {
                            Task {
                                await viewModel.selectCategory(nil)
                            }
                        }
                        
                        ForEach(viewModel.categories) { category in
                            CategoryChip(
                                title: category.title,
                                imageURL: category.thumb.url,
                                isSelected: viewModel.selectedCategory == category.title
                            ) {
                                Task {
                                    await viewModel.selectCategory(category.title)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .padding(.horizontal, 16)
            }
        }
    }
    
    private var comicsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.selectedCategory ?? localization.text("home.latest"))
                    .font(.system(size: 28, weight: .bold))
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
                    ComicCard(comic: comic)
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
            Image(systemName: "book.closed")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.45))
            Text(localization.text("home.empty.title"))
                .font(.system(size: 18, weight: .semibold))
            Text(localization.text("home.empty.subtitle"))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
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

struct CategoryChip: View {
    let title: String
    let imageURL: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let imageURL {
                    ComicCoverImage(url: imageURL)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        )
                }
                
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
