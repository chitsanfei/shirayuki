import Foundation

nonisolated enum PicaAgentAdapters {
    static func isBlocked(_ summary: ComicSummary, snapshot: BlockedWordSnapshot) -> Bool {
        !BlockedWordMatcher.isVisible(
            fields: [summary.title, summary.author] + summary.categories + summary.tags,
            snapshot: snapshot
        )
    }

    static func visibleComics(_ comics: [ComicSummary], snapshot: BlockedWordSnapshot) -> [ComicSummary] {
        comics.filter { !isBlocked($0, snapshot: snapshot) }
    }

    static func searchItems(_ comics: [ComicSummary], snapshot: BlockedWordSnapshot) -> [AgentSearchItem] {
        visibleComics(comics, snapshot: snapshot).map(AgentSearchItem.init)
    }

    static func favoriteItems(_ comics: [ComicSummary], snapshot: BlockedWordSnapshot) -> [AgentFavoriteItem] {
        visibleComics(comics, snapshot: snapshot).map(AgentFavoriteItem.init)
    }

    static func visibleItem(_ summary: ComicSummary) -> AgentVisibleComicItem {
        AgentVisibleComicItem(
            comicID: summary.id,
            title: summary.title,
            author: summary.author,
            categories: Array(summary.categories.prefix(20)),
            tags: Array(summary.tags.prefix(20)),
            chapterCount: summary.epsCount,
            finished: summary.finished
        )
    }

    static func pageContent(
        source: String,
        title: String,
        comics: [ComicSummary],
        itemLimit: Int = AgentPageContentSnapshot.defaultComicItemLimit
    ) -> AgentPageContentSnapshot {
        let limit = min(
            max(itemLimit, AgentPageContentSnapshot.defaultComicItemLimit),
            AgentPageContentSnapshot.maximumComicItems
        )
        let items = itemLimit == AgentPageContentSnapshot.defaultComicItemLimit
            ? comics.prefix(limit)
            : comics.suffix(limit)
        return .comicList(
            source: source,
            title: title,
            items: items.map(visibleItem),
            totalVisible: comics.count
        )
    }

    static func detailContent(
        _ detail: ComicDetail,
        recommendations: [ComicSummary],
        isLiked: Bool,
        isFavorited: Bool
    ) -> AgentPageContentSnapshot {
        .comicDetail(AgentComicDetailSnapshot(
            comicID: detail.id,
            title: detail.title,
            author: detail.author ?? detail.creator.name,
            summary: String(detail.description.prefix(2_000)),
            categories: Array(detail.categories.prefix(20)),
            tags: Array(detail.tags.prefix(20)),
            chapterCount: detail.epsCount,
            pageCount: detail.pagesCount,
            totalViews: detail.totalViews,
            likesCount: detail.likesCount,
            finished: detail.finished,
            isLiked: isLiked,
            isFavorited: isFavorited,
            recommendations: recommendations
                .prefix(AgentPageContentSnapshot.maximumRecommendations)
                .map(visibleItem)
        ))
    }
}

nonisolated extension AgentFavoriteItem {
    init(_ summary: ComicSummary) {
        self.init(
            comicID: summary.id,
            title: summary.title,
            author: summary.author,
            chapterCount: summary.epsCount,
            finished: summary.finished
        )
    }
}

nonisolated extension AgentLibraryItem {
    init(_ record: OfflineComicRecord) {
        self.init(
            comicID: record.id,
            title: record.title,
            chapterCount: record.chapters.count,
            imageCount: record.imageCount,
            quality: record.quality,
            byteCount: record.byteCount,
            downloadedAt: record.downloadedAt
        )
    }
}

nonisolated extension AgentSearchItem {
    init(_ summary: ComicSummary) {
        self.init(
            comicID: summary.id,
            title: summary.title,
            author: summary.author,
            chapterCount: summary.epsCount,
            finished: summary.finished
        )
    }
}

nonisolated extension AgentRedactor {
    static func user(_ profile: UserProfileResponse, favoriteCount: Int? = nil) -> AgentUserSnapshot {
        AgentUserSnapshot(
            displayName: profile.name,
            level: profile.level,
            exp: profile.exp,
            isPunched: profile.isPunched,
            favoriteCount: favoriteCount
        )
    }
}
nonisolated struct DefaultAgentUserProvider: AgentUserProvider {
    func currentUser() async throws -> AgentUserSnapshot {
        AgentRedactor.user(try await PicaAPIService.shared.fetchUserProfile())
    }
}

nonisolated struct DefaultAgentLibraryProvider: AgentLibraryProvider {
    private let blockedWords: any BlockedWordRepository

    init(blockedWords: any BlockedWordRepository) {
        self.blockedWords = blockedWords
    }

    func favoritePage(page: Int, sort: ComicSortType) async throws -> [AgentFavoriteItem] {
        guard (1...100).contains(page) else { throw AgentCommandError.invalidPage }
        let result = try await PicaAPIService.shared.fetchFavoriteComics(page: page, sort: sort)
        return PicaAgentAdapters.favoriteItems(result.docs, snapshot: await blockedWords.snapshot())
    }

    func offlineLibrary() async -> AgentOfflineLibrarySnapshot {
        let records = await OfflineComicStore.shared.allComics()
        return AgentOfflineLibrarySnapshot(
            items: Array(records.prefix(AgentOfflineLibrarySnapshot.defaultItemLimit).map(AgentLibraryItem.init)),
            totalCount: records.count,
            storageBytes: await OfflineComicStore.shared.storageSize()
        )
    }
}

nonisolated struct DefaultAgentDownloadProvider: AgentDownloadProvider {
    func activeDownloads() async -> [AgentDownloadSnapshot] {
        await DownloadCoordinator.shared.activeSnapshots()
    }

    func snapshot(jobID: String) async throws -> AgentDownloadSnapshot {
        do {
            return try await DownloadCoordinator.shared.snapshot(jobID: jobID)
        } catch {
            throw AgentCommandError.invalidIdentifier
        }
    }
}
