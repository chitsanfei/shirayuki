import XCTest
@testable import Shirayuki

final class DownloadCoordinatorTests: XCTestCase {
    func testConflictReportsEveryExistingJobAndRejectsWholeRequestAtKeyBoundary() {
        let occupied: [DownloadCoordinator.DownloadChapterKey: String] = [
            .init(comicID: "comic", chapterID: "chapter-1"): "job-a",
            .init(comicID: "comic", chapterID: "chapter-2"): "job-b"
        ]

        let conflicts = DownloadCoordinator.conflictingJobIDs(
            comicID: "comic",
            chapterIDs: ["chapter-2", "chapter-1"],
            occupiedKeys: occupied
        )

        XCTAssertEqual(conflicts, ["job-a", "job-b"])
    }

    func testDifferentComicDoesNotConflictOnSameChapterID() {
        let occupied: [DownloadCoordinator.DownloadChapterKey: String] = [
            .init(comicID: "comic-a", chapterID: "chapter-1"): "job-a"
        ]

        XCTAssertTrue(
            DownloadCoordinator.conflictingJobIDs(
                comicID: "comic-b",
                chapterIDs: ["chapter-1"],
                occupiedKeys: occupied
            ).isEmpty
        )
    }
}
