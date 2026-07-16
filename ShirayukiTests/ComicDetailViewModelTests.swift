import XCTest
@testable import Shirayuki

@MainActor
final class ComicDetailViewModelTests: XCTestCase {
    func testOfflineChapterStateSupportsPartialComicDownloads() {
        let viewModel = ComicDetailViewModel(comicId: "offline-state-comic")
        let chapters = [
            PicaChapter(uid: "uid-1", title: "第1话", order: 1, id: "chapter-1"),
            PicaChapter(uid: "uid-2", title: "第2话", order: 2, id: "chapter-2")
        ]
        viewModel.chapters = chapters
        viewModel.offlineRecord = makeRecord(chapters: [chapters[0]])

        XCTAssertEqual(viewModel.offlineChapterIDs, ["chapter-1"])
        XCTAssertFalse(viewModel.isFullyOffline)

        viewModel.offlineRecord = makeRecord(chapters: chapters)

        XCTAssertTrue(viewModel.isFullyOffline)
    }

    private func makeRecord(chapters: [PicaChapter]) -> OfflineComicRecord {
        OfflineComicRecord(
            id: "offline-state-comic",
            title: "Test Comic",
            thumbURL: "",
            createdAt: "",
            updatedAt: "",
            downloadedAt: Date(),
            quality: .original,
            chapters: chapters.map {
                OfflineChapterRecord(
                    id: $0.id,
                    title: $0.title,
                    order: $0.order,
                    quality: .original,
                    images: []
                )
            }
        )
    }
}
