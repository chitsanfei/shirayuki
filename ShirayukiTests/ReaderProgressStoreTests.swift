import XCTest
@testable import Shirayuki

@MainActor
final class ReaderProgressStoreTests: XCTestCase {
    private let comicId = "test-comic-progress"

    override func tearDown() {
        ReaderProgressStore.shared.clearProgress(for: comicId)
        super.tearDown()
    }

    func testSaveAndLoadReaderProgress() {
        ReaderProgressStore.shared.save(
            comicId: comicId,
            chapterId: "chapter-1",
            chapterTitle: "第1话",
            chapterOrder: 1,
            pageIndex: 7
        )

        let progress = ReaderProgressStore.shared.progress(for: comicId)

        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.comicId, comicId)
        XCTAssertEqual(progress?.chapterId, "chapter-1")
        XCTAssertEqual(progress?.chapterTitle, "第1话")
        XCTAssertEqual(progress?.chapterOrder, 1)
        XCTAssertEqual(progress?.pageIndex, 7)
    }

    func testClearReaderProgressRemovesStoredRecord() {
        ReaderProgressStore.shared.save(
            comicId: comicId,
            chapterId: "chapter-2",
            chapterTitle: "第2话",
            chapterOrder: 2,
            pageIndex: 3
        )

        ReaderProgressStore.shared.clearProgress(for: comicId)

        XCTAssertNil(ReaderProgressStore.shared.progress(for: comicId))
    }
}
