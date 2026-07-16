import Foundation
import Combine

enum ComicDownloadState: Equatable {
    case idle
    case downloading(completedImages: Int, totalImages: Int)
    case completed
    case failed(String)
}

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

    var offlineChapterIDs: Set<String> {
        Set(offlineRecord?.chapters.map(\.id) ?? [])
    }

    var isFullyOffline: Bool {
        !chapters.isEmpty && chapters.allSatisfy { offlineChapterIDs.contains($0.id) }
    }

    func startDownload(quality: AppImageQuality, chapters selectedChapters: [PicaChapter]) {
        guard let comic, !selectedChapters.isEmpty else { return }
        downloadTask?.cancel()
        downloadState = .downloading(completedImages: 0, totalImages: 0)
        let comicID = comic.id
        let title = comic.title
        let thumbURL = comic.thumb.url
        let createdAt = comic.createdAt
        let updatedAt = comic.updatedAt
        let chapters = selectedChapters
        downloadTask = Task(priority: .utility) { [weak self] in
            do {
                try await OfflineComicStore.shared.download(
                    comicID: comicID,
                    title: title,
                    thumbURL: thumbURL,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    chapters: chapters,
                    quality: quality,
                    progress: { progress in
                        Task { @MainActor [weak self] in
                            self?.downloadState = .downloading(
                                completedImages: progress.completedImages,
                                totalImages: progress.totalImages
                            )
                            if progress.totalImages > 0,
                               progress.completedImages == progress.totalImages {
                                await self?.refreshOfflineRecord()
                            }
                        }
                    }
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.downloadState = .completed
                    Task { await self?.refreshOfflineRecord() }
                }
            } catch is CancellationError {
            } catch {
                await MainActor.run {
                    self?.downloadState = .failed(error.localizedDescription)
                    Task { await self?.refreshOfflineRecord() }
                }
            }
        }
    }
}
