import Foundation
import XCTest
@testable import Shirayuki

@MainActor
final class ReaderViewModelTests: XCTestCase {
    func testResolvedInitialChapterIndexPrefersChapterIdentityBeforeFallbackIndex() throws {
        let comic = try makeComic(id: "resume-comic")
        let chapters = [
            try makeChapter(uid: "uid-1", id: "chapter-1", title: "第1话", order: 1),
            try makeChapter(uid: "uid-2", id: "chapter-2", title: "第2话", order: 2),
            try makeChapter(uid: "uid-3", id: "chapter-3", title: "第3话", order: 3)
        ]

        let chapterIdViewModel = ReaderViewModel(
            comic: comic,
            initialChapters: chapters,
            initialChapterIndex: 0,
            initialChapterId: "chapter-2",
            initialChapterOrder: 3
        )
        XCTAssertEqual(chapterIdViewModel.resolvedInitialChapterIndex(in: chapters), 1)

        let chapterOrderViewModel = ReaderViewModel(
            comic: comic,
            initialChapters: chapters,
            initialChapterIndex: 0,
            initialChapterId: "missing-chapter",
            initialChapterOrder: 3
        )
        XCTAssertEqual(chapterOrderViewModel.resolvedInitialChapterIndex(in: chapters), 2)

        let fallbackIndexViewModel = ReaderViewModel(
            comic: comic,
            initialChapters: chapters,
            initialChapterIndex: 2
        )
        XCTAssertEqual(fallbackIndexViewModel.resolvedInitialChapterIndex(in: chapters), 2)
    }

    func testCancelOngoingWorkPersistsLatestProgressImmediately() throws {
        let comic = try makeComic(id: "persist-comic")
        let chapter = try makeChapter(uid: "uid-10", id: "chapter-10", title: "第10话", order: 10)
        let images = try (1...6).map { index in
            try makeImage(uid: "page-\(index)", path: "/comic/\(index).jpg")
        }

        defer {
            ReaderProgressStore.shared.clearProgress(for: comic.id)
        }
        ReaderProgressStore.shared.clearProgress(for: comic.id)

        let viewModel = ReaderViewModel(
            comic: comic,
            initialChapters: [chapter],
            initialChapterIndex: 0,
            initialChapterId: chapter.id,
            initialChapterOrder: chapter.order
        )
        viewModel.chapters = [chapter]
        viewModel.currentChapterIndex = 0
        viewModel.images = images
        viewModel.currentChapterTitle = chapter.title
        viewModel.currentPageIndex = 4

        viewModel.cancelOngoingWork()

        let progress = ReaderProgressStore.shared.progress(for: comic.id)
        XCTAssertEqual(progress?.chapterId, chapter.id)
        XCTAssertEqual(progress?.chapterTitle, chapter.title)
        XCTAssertEqual(progress?.chapterOrder, chapter.order)
        XCTAssertEqual(progress?.pageIndex, 4)
    }
}

private func makeComic(id: String) throws -> ComicDetail {
    let data = Data(
        """
        {
          "_id": "\(id)",
          "_creator": {
            "_id": "creator-1",
            "gender": "",
            "name": "Creator",
            "exp": 0,
            "level": 0,
            "role": "",
            "characters": [],
            "title": ""
          },
          "title": "Test Comic",
          "description": "",
          "thumb": {
            "fileServer": "https://storage1.picacomic.com",
            "path": "/covers/test.jpg",
            "originalName": "test.jpg"
          },
          "author": "Author",
          "categories": [],
          "chineseTeam": "",
          "tags": [],
          "pagesCount": 10,
          "epsCount": 3,
          "finished": false,
          "updated_at": "2026-05-04",
          "created_at": "2026-05-01",
          "allowDownload": true,
          "allowComment": true,
          "totalLikes": 0,
          "totalViews": 0,
          "viewsCount": 0,
          "likesCount": 0,
          "commentsCount": 0,
          "isFavourite": false,
          "isLiked": false
        }
        """.utf8
    )
    return try JSONDecoder().decode(ComicDetail.self, from: data)
}

private func makeChapter(uid: String, id: String, title: String, order: Int) throws -> PicaChapter {
    let data = Data(
        """
        {
          "_id": "\(uid)",
          "id": "\(id)",
          "title": "\(title)",
          "order": \(order),
          "updated_at": "2026-05-04"
        }
        """.utf8
    )
    return try JSONDecoder().decode(PicaChapter.self, from: data)
}

private func makeImage(uid: String, path: String) throws -> ChapterImage {
    let data = Data(
        """
        {
          "_id": "\(uid)",
          "id": "\(uid)",
          "media": {
            "fileServer": "https://storage1.picacomic.com",
            "path": "\(path)",
            "originalName": "page.jpg"
          }
        }
        """.utf8
    )
    return try JSONDecoder().decode(ChapterImage.self, from: data)
}
