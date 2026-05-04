import SwiftUI

struct CategoriesView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var localization = AppLocalization.shared
    
    private let columns = [
        GridItem(.adaptive(minimum: 108, maximum: 150), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let errorMessage = viewModel.errorMessage, viewModel.categories.isEmpty, !viewModel.isLoading {
                        contentErrorState(message: errorMessage)
                    } else if viewModel.categories.isEmpty, viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else if viewModel.categories.isEmpty {
                        contentEmptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(viewModel.categories.enumerated()), id: \.element.id) { index, category in
                                NavigationLink(destination: ComicsBrowserView(source: .category(category.title))) {
                                    CategoryGridItem(category: category)
                                }
                                .buttonStyle(.plain)
                                .lazyGridReveal(index: index)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 120)
            }
            .navigationTitle(localization.text("categories.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await viewModel.loadCategories()
            }
            .task {
                guard viewModel.categories.isEmpty else { return }
                await viewModel.loadCategories()
            }
        }
    }
    
    private var contentEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.45))
            Text(localization.text("categories.empty.title"))
                .font(.system(size: 18, weight: .semibold))
            Text(localization.text("categories.empty.subtitle"))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
    
    private func contentErrorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(localization.text("common.reload")) {
                Task {
                    await viewModel.loadCategories()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}

struct CategoryGridItem: View {
    let category: PicaCategory
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                ComicCoverImage(url: category.thumb.url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            }
            
            Text(category.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
        }
    }
}
