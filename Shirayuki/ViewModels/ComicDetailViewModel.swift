import Foundation
import Combine

/// Download lifecycle displayed by the comic detail screen.
enum ComicDownloadState: Equatable {
    case idle
    case downloading(completedImages: Int, totalImages: Int)
    case completed
    case failed(String)
}

/// Coordinates comic metadata, chapter actions, and offline download state.
@MainActor
final class ComicDetailViewModel: ObservableViewModel {
    @Published var comic: ComicDetail?
    @Published var chapters: [PicaChapter] = []
    @Published var recommendations: [ComicSummary] = []
    @Published var readProgress: ReaderProgress?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLiked = false
    @Published var isFavorited = false
    @Published var downloadState: ComicDownloadState = .idle
    @Published var offlineRecord: OfflineComicRecord?
    
    let comicId: String
    private var downloadTask: Task<Void, Never>?
    private var downloadJobID: String?
    
    init(comicId: String) {
        self.comicId = comicId
    }
    
    func loadDetail() async {
        isLoading = true
        errorMessage = nil
        readProgress = ReaderProgressStore.shared.progress(for: comicId)
        defer { isLoading = false }
        do {
            let detail = try await PicaAPIService.shared.fetchComicDetail(id: comicId)
            comic = detail
            isLiked = detail.isLiked
            isFavorited = detail.isFavourite

            async let chaptersTask: [PicaChapter] = PicaAPIService.shared.fetchChapters(id: comicId)
            async let recommendTask: [ComicSummary] = PicaAPIService.shared.fetchRecommendations(id: comicId)

            do {
                let chaptersResult = try await chaptersTask
                chapters = chaptersResult.sorted { $0.order < $1.order }
            } catch {
                chapters = []
                handleError(error)
            }

            do {
                recommendations = try await recommendTask
            } catch {
                recommendations = []
            }
            await refreshOfflineRecord()
        } catch {
            comic = nil
            chapters = []
            recommendations = []
            handleError(error)
        }
    }

    func refreshReadProgress() {
        readProgress = ReaderProgressStore.shared.progress(for: comicId)
    }
    
    func toggleLike() async {
        do {
            _ = try await PicaAPIService.shared.likeComic(id: comicId)
            isLiked.toggle()
        } catch {
            handleError(error)
        }
    }

    func toggleFavorite() async {
        do {
            _ = try await PicaAPIService.shared.favoriteComic(id: comicId)
            isFavorited.toggle()
        } catch {
            handleError(error)
        }
    }

    func refreshOfflineRecord() async {
        offlineRecord = await OfflineComicStore.shared.record(for: comicId)
    }

    nonisolated static func offlineChapterIDs(in record: OfflineComicRecord?) -> Set<String> {
        Set(record?.chapters.map(\.id) ?? [])
    }

    nonisolated static func isFullyOffline(
        chapters: [PicaChapter],
        offlineChapterIDs: Set<String>
    ) -> Bool {
        !chapters.isEmpty && chapters.allSatisfy { offlineChapterIDs.contains($0.id) }
    }

    var offlineChapterIDs: Set<String> {
        Self.offlineChapterIDs(in: offlineRecord)
    }

    var isFullyOffline: Bool {
        Self.isFullyOffline(chapters: chapters, offlineChapterIDs: offlineChapterIDs)
    }

    func startDownload(quality: AppImageQuality, chapters selectedChapters: [PicaChapter]) {
        guard let comic, !selectedChapters.isEmpty else { return }
        if let previousJobID = downloadJobID {
            Task {
                try? await DownloadCoordinator.shared.cancel(jobID: previousJobID)
            }
        }
        downloadTask?.cancel()
        downloadState = .downloading(completedImages: 0, totalImages: 0)

        let request = DownloadRequest(
            comicID: comic.id,
            title: comic.title,
            thumbURL: comic.thumb.url,
            createdAt: comic.createdAt,
            updatedAt: comic.updatedAt,
            chapters: selectedChapters,
            quality: quality,
            allChapters: chapters,
            allowDownload: comic.allowDownload
        )
        downloadTask = Task { @MainActor [weak self] in
            do {
                let jobID = try await DownloadCoordinator.shared.start(request: request)
                guard let self else { return }
                self.downloadJobID = jobID
                let updates = await DownloadCoordinator.shared.updates(for: jobID)
                for await snapshot in updates {
                    guard !Task.isCancelled else { return }
                    switch snapshot.state {
                    case .queued, .downloading:
                        self.downloadState = .downloading(
                            completedImages: snapshot.completedImages,
                            totalImages: snapshot.totalImages
                        )
                    case .completed:
                        self.downloadState = .completed
                        self.downloadJobID = nil
                        await self.refreshOfflineRecord()
                        return
                    case .failed:
                        self.downloadState = .failed(snapshot.errorMessage ?? "download_failed")
                        self.downloadJobID = nil
                        await self.refreshOfflineRecord()
                        return
                    case .cancelled:
                        self.downloadJobID = nil
                        return
                    }
                }
            } catch is CancellationError {
            } catch {
                self?.downloadJobID = nil
                self?.downloadState = .failed("download_failed")
                await self?.refreshOfflineRecord()
            }
        }
    }
}
