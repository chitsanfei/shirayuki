import Foundation
import Combine

@MainActor
final class ComicDetailViewModel: ObservableObject {
    @Published var comic: ComicDetail?
    @Published var chapters: [PicaChapter] = []
    @Published var recommendations: [RecommendComic] = []
    @Published var readProgress: ReaderProgress?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLiked = false
    @Published var isFavorited = false
    
    let comicId: String
    
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
            async let recommendTask: [RecommendComic] = PicaAPIService.shared.fetchRecommendations(id: comicId)

            do {
                let chaptersResult = try await chaptersTask
                chapters = chaptersResult.sorted { $0.order < $1.order }
            } catch {
                chapters = []
                errorMessage = error.localizedDescription
            }

            do {
                recommendations = try await recommendTask
            } catch {
                recommendations = []
            }
        } catch {
            comic = nil
            chapters = []
            recommendations = []
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }
    
    func toggleFavorite() async {
        do {
            _ = try await PicaAPIService.shared.favoriteComic(id: comicId)
            isFavorited.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
