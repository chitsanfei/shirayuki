import SwiftUI

struct ComicDetailView: View {
    let comicId: String
    
    @StateObject private var viewModel: ComicDetailViewModel
    @ObservedObject private var localization = AppLocalization.shared
    @State private var showReader = false
    @State private var readerStartChapterIndex = 0
    @State private var readerStartChapterId: String?
    @State private var readerStartChapterOrder: Int?
    @State private var readerStartPageIndex = 0
    @State private var routedComicId: String?
    @State private var showAllChapters = false
    @State private var chapterSortOrder: ChapterSortOrder = .ascending
    init(comicId: String) {
        self.comicId = comicId
        _viewModel = StateObject(wrappedValue: ComicDetailViewModel(comicId: comicId))
    }
    
    var body: some View {
        ScrollView {
            if let comic = viewModel.comic {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection(comic: comic)
                    quickStatsSection(comic: comic)
                    creatorSection(comic: comic)
                    tagSection(title: localization.text("detail.section.categories"), values: comic.categories)
                    tagSection(title: localization.text("detail.section.tags"), values: comic.tags)
                    actionSection(comic: comic)
                    readProgressSection
                    chapterSection
                    descriptionSection(comic: comic)
                    recommendationSection
                }
                .padding(.vertical, 16)
                .padding(.bottom, 24)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
            } else if let errorMessage = viewModel.errorMessage {
                detailErrorState(message: errorMessage)
                    .padding(.top, 120)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(localization.text("detail.loading"))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 120)
            }
        }
        .navigationTitle(viewModel.comic?.title ?? localization.text("detail.title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $routedComicId) { nextComicId in
            ComicDetailView(comicId: nextComicId)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showReader, onDismiss: viewModel.refreshReadProgress) {
            if let comic = viewModel.comic {
                ReaderView(
                    viewModel: ReaderViewModel(
                        comic: comic,
                        initialChapters: viewModel.chapters,
                        initialChapterIndex: readerStartChapterIndex,
                        initialChapterId: readerStartChapterId,
                        initialChapterOrder: readerStartChapterOrder,
                        initialPageIndex: readerStartPageIndex
                    )
                )
            }
        }
        #else
        .sheet(isPresented: $showReader, onDismiss: viewModel.refreshReadProgress) {
            if let comic = viewModel.comic {
                ReaderView(
                    viewModel: ReaderViewModel(
                        comic: comic,
                        initialChapters: viewModel.chapters,
                        initialChapterIndex: readerStartChapterIndex,
                        initialChapterId: readerStartChapterId,
                        initialChapterOrder: readerStartChapterOrder,
                        initialPageIndex: readerStartPageIndex
                    )
                )
            }
        }
        #endif
        .task(id: comicId) {
            await viewModel.loadDetail()
        }
    }
    
    private func startReading(at chapterIndex: Int = 0, pageIndex: Int = 0) {
        let clampedIndex = min(max(chapterIndex, 0), max(0, viewModel.chapters.count - 1))
        let chapter = viewModel.chapters.indices.contains(clampedIndex) ? viewModel.chapters[clampedIndex] : nil
        readerStartChapterIndex = clampedIndex
        readerStartChapterId = chapter?.id
        readerStartChapterOrder = chapter?.order
        readerStartPageIndex = pageIndex
        showReader = true
    }

    private func startReading(chapterId: String?, chapterOrder: Int?, pageIndex: Int = 0) {
        guard !viewModel.chapters.isEmpty else { return }
        let chapterIndex = if let chapterId,
                              let matchedIndex = viewModel.chapters.firstIndex(where: { $0.id == chapterId }) {
            matchedIndex
        } else if let chapterOrder,
                  let matchedIndex = viewModel.chapters.firstIndex(where: { $0.order == chapterOrder }) {
            matchedIndex
        } else if let progress = viewModel.readProgress,
                  let matchedIndex = viewModel.chapters.firstIndex(where: {
                      $0.id == progress.chapterId || $0.order == progress.chapterOrder
                  }) {
            matchedIndex
        } else {
            0
        }
        startReading(at: chapterIndex, pageIndex: pageIndex)
    }

    private var sortedChapterEntries: [(index: Int, chapter: PicaChapter)] {
        let entries = viewModel.chapters.enumerated().map { (index: $0.offset, chapter: $0.element) }
        switch chapterSortOrder {
        case .ascending:
            return entries
        case .descending:
            return Array(entries.reversed())
        }
    }

    private var displayedChapterEntries: [(index: Int, chapter: PicaChapter)] {
        if showAllChapters || sortedChapterEntries.count <= 40 {
            return sortedChapterEntries
        }
        return Array(sortedChapterEntries.prefix(40))
    }
    
    private func headerSection(comic: ComicDetail) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ComicCoverImage(url: comic.thumb.url)
                .aspectRatio(2 / 3, contentMode: .fill)
                .frame(width: 118, height: 172)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(comic.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                
                if let author = comic.author, !author.isEmpty {
                    Label(author, systemImage: "person.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                
                if !comic.chineseTeam.isEmpty {
                    Label(comic.chineseTeam, systemImage: "character.book.closed.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                
                HStack(spacing: 14) {
                    InfoBadge(icon: "heart.fill", text: "\(comic.totalLikes)", color: .pink)
                    InfoBadge(icon: "eye.fill", text: "\(comic.totalViews)", color: .orange)
                    InfoBadge(icon: "doc.on.doc.fill", text: localization.text("detail.badge.pages", comic.pagesCount), color: .green)
                }
                
                Text(comic.finished ? localization.text("comic.status.finished") : localization.text("detail.status.ongoing"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(comic.finished ? .green : .secondary)
                
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
    
    private func quickStatsSection(comic: ComicDetail) -> some View {
        HStack(spacing: 0) {
            StatBlock(value: "\(comic.epsCount)", title: localization.text("detail.stats.chapters"))
            Divider().frame(height: 40)
            StatBlock(value: "\(comic.commentsCount)", title: localization.text("detail.stats.comments"))
            Divider().frame(height: 40)
            StatBlock(value: comic.updatedAt.prefix(10).description, title: localization.text("detail.stats.updated"))
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func creatorSection(comic: ComicDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(localization.text("detail.section.info"))

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    if let avatarURL = comic.creator.avatar?.url {
                        ComicAsyncImage(url: avatarURL)
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.secondary.opacity(0.16))
                            .frame(width: 52, height: 52)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.secondary)
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(comic.creator.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                        if !comic.creator.title.isEmpty {
                            Text(comic.creator.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        if let slogan = comic.creator.slogan, !slogan.isEmpty {
                            Text(slogan)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    MetaChip(icon: "clock", text: localization.text("detail.meta.updated", comic.updatedAt.prefix(10).description))
                    MetaChip(icon: "calendar", text: localization.text("detail.meta.created", comic.createdAt.prefix(10).description))
                }

                HStack(spacing: 10) {
                    MetaChip(
                        icon: comic.allowDownload ? "arrow.down.circle.fill" : "arrow.down.circle",
                        text: comic.allowDownload ? localization.text("detail.meta.download.enabled") : localization.text("detail.meta.download.disabled")
                    )
                    MetaChip(
                        icon: comic.allowComment ? "text.bubble.fill" : "text.bubble",
                        text: comic.allowComment ? localization.text("detail.meta.comment.enabled") : localization.text("detail.meta.comment.disabled")
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private func tagSection(title: String, values: [String]) -> some View {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(title)
                FlowLayout(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func actionSection(comic: ComicDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(localization.text("detail.section.actions"))
            
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.toggleLike() }
                } label: {
                    ActionButtonLabel(
                        icon: viewModel.isLiked ? "heart.fill" : "heart",
                        title: viewModel.isLiked ? localization.text("detail.action.liked") : localization.text("detail.action.like"),
                        isFilled: viewModel.isLiked,
                        tint: .pink
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    Task { await viewModel.toggleFavorite() }
                } label: {
                    ActionButtonLabel(
                        icon: viewModel.isFavorited ? "star.fill" : "star",
                        title: viewModel.isFavorited ? localization.text("detail.action.favorited") : localization.text("detail.action.favorite"),
                        isFilled: viewModel.isFavorited,
                        tint: .yellow
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    startReading(at: 0, pageIndex: 0)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                        Text(localization.text("detail.action.startReading"))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var readProgressSection: some View {
        if let progress = viewModel.readProgress {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(localization.text("detail.section.progress"))

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(localization.text("detail.progress.lastRead"), systemImage: "bookmark.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(progress.chapterTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(localization.text("detail.progress.page", progress.pageIndex + 1))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(localization.text("detail.action.continueReading")) {
                        startReading(
                            chapterId: progress.chapterId,
                            chapterOrder: progress.chapterOrder,
                            pageIndex: progress.pageIndex
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.chapters.isEmpty)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
                )
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var chapterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(localization.text("detail.section.chapters"))
                Spacer()

                Button {
                    chapterSortOrder.toggle()
                } label: {
                    Label(chapterSortOrder.buttonTitle, systemImage: chapterSortOrder.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
            
            if viewModel.chapters.isEmpty && viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .padding(.horizontal, 16)
            } else if viewModel.chapters.isEmpty {
                VStack(spacing: 10) {
                    Text(viewModel.errorMessage == nil ? localization.text("detail.chapters.empty") : localization.text("detail.chapters.loadFailed"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)

                    if viewModel.errorMessage != nil {
                        Button(localization.text("common.reload")) {
                            Task {
                                await viewModel.loadDetail()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding(.horizontal, 16)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 10)], spacing: 10) {
                    ForEach(displayedChapterEntries, id: \.index) { entry in
                        Button {
                            startReading(at: entry.index, pageIndex: 0)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.chapter.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(localization.text("detail.chapters.item", entry.chapter.order))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                if viewModel.chapters.count > 40 {
                    Button(showAllChapters ? localization.text("detail.chapters.collapse") : localization.text("detail.chapters.expand")) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllChapters.toggle()
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private func descriptionSection(comic: ComicDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(localization.text("detail.section.description"))
            Text(comic.description.isEmpty ? localization.text("detail.description.empty") : comic.description)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.horizontal, 16)
        }
    }
    
    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(localization.text("detail.section.recommendations"))
            
            if viewModel.recommendations.isEmpty && viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .padding(.horizontal, 16)
            } else if viewModel.recommendations.isEmpty {
                Text(localization.text("detail.recommendations.empty"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.recommendations) { comic in
                            VStack(alignment: .leading, spacing: 8) {
                                ComicCoverImage(url: comic.thumb.url)
                                    .aspectRatio(2 / 3, contentMode: .fill)
                                    .frame(width: 112, height: 154)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                
                                Text(comic.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .frame(width: 112, alignment: .leading)

                                if !comic.author.isEmpty {
                                    Text(comic.author)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 112, alignment: .leading)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                routedComicId = comic.id
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
    }
    
    private func detailErrorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 38))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(localization.text("common.reload")) {
                Task {
                    await viewModel.loadDetail()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

private enum ChapterSortOrder {
    case ascending
    case descending

    var buttonTitle: String {
        switch self {
        case .ascending:
            return AppLocalization.text("detail.sort.ascending")
        case .descending:
            return AppLocalization.text("detail.sort.descending")
        }
    }

    var iconName: String {
        switch self {
        case .ascending:
            return "arrow.up.to.line"
        case .descending:
            return "arrow.down.to.line"
        }
    }

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

private struct InfoBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .semibold))
    }
}

private struct StatBlock: View {
    let value: String
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ActionButtonLabel: View {
    let icon: String
    let title: String
    let isFilled: Bool
    let tint: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(isFilled ? .white : tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(isFilled ? tint : tint.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MetaChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
