import Foundation
import XCTest
@testable import Shirayuki

/// Verifies offline catalog persistence and legacy record compatibility.
final class OfflineComicCatalogTests: XCTestCase {
    func testRecordKeepsFullCatalogAlongsideDownloadedSubset() throws {
        let record = makeRecord(
            availableChapters: [
                PicaChapter(uid: "chapter-1", title: "第1话", order: 1, id: "chapter-1"),
                PicaChapter(uid: "chapter-2", title: "第2话", order: 2, id: "chapter-2")
            ]
        )
        let decoded = try JSONDecoder().decode(
            OfflineComicRecord.self,
            from: JSONEncoder().encode(record)
        )

        XCTAssertEqual(decoded.chapterCatalog.map(\.id), ["chapter-1", "chapter-2"])
        XCTAssertEqual(decoded.chapters.map(\.id), ["chapter-1"])
    }

    func testLegacyRecordFallsBackToDownloadedChapterCatalog() throws {
        let data = try JSONEncoder().encode(makeRecord(availableChapters: []))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "availableChapters")

        let decoded = try JSONDecoder().decode(
            OfflineComicRecord.self,
            from: JSONSerialization.data(withJSONObject: json)
        )

        XCTAssertEqual(decoded.chapterCatalog.map(\.id), ["chapter-1"])
    }

    func testDownloadProgressClampsFraction() {
        XCTAssertNil(OfflineDownloadProgress(completedImages: 0, totalImages: 0).fraction)
        XCTAssertEqual(
            OfflineDownloadProgress(completedImages: 3, totalImages: 4).fraction,
            0.75
        )
        XCTAssertEqual(
            OfflineDownloadProgress(completedImages: 5, totalImages: 4).fraction,
            1
        )
    }

    private func makeRecord(availableChapters: [PicaChapter]) -> OfflineComicRecord {
        OfflineComicRecord(
            id: "offline-catalog",
            title: "Test",
            thumbURL: "",
            createdAt: "",
            updatedAt: "",
            downloadedAt: Date(timeIntervalSince1970: 0),
            quality: .original,
            availableChapters: availableChapters.map(OfflineChapterMetadata.init),
            chapters: [
                OfflineChapterRecord(
                    id: "chapter-1",
                    title: "第1话",
                    order: 1,
                    quality: .original,
                    images: []
                )
            ]
        )
    }
}
