import XCTest
@testable import Shirayuki

final class ComicDetailViewModelTests: XCTestCase {
    func testOfflineChapterStateSupportsPartialComicDownloads() {
        let chapters = [
            PicaChapter(uid: "uid-1", title: "第1话", order: 1, id: "chapter-1"),
            PicaChapter(uid: "uid-2", title: "第2话", order: 2, id: "chapter-2")
        ]
        let partialIDs = ComicDetailViewModel.offlineChapterIDs(
            in: makeRecord(chapters: [chapters[0]])
        )

        XCTAssertEqual(partialIDs, ["chapter-1"])
        XCTAssertFalse(
            ComicDetailViewModel.isFullyOffline(
                chapters: chapters,
                offlineChapterIDs: partialIDs
            )
        )

        let completeIDs = ComicDetailViewModel.offlineChapterIDs(
            in: makeRecord(chapters: chapters)
        )
        XCTAssertTrue(
            ComicDetailViewModel.isFullyOffline(
                chapters: chapters,
                offlineChapterIDs: completeIDs
            )
        )
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
