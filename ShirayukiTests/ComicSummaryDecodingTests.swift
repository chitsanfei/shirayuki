import Foundation
import XCTest
@testable import Shirayuki

final class ComicSummaryDecodingTests: XCTestCase {
    private func decode(_ json: String) throws -> ComicSummary {
        try JSONDecoder().decode(ComicSummary.self, from: Data(json.utf8))
    }

    func testFullPayloadDecodesAllFields() throws {
        let json = """
        {
          "_id": "comic-1",
          "title": "Title",
          "author": "Author",
          "thumb": {
            "fileServer": "https://storage1.picacomic.com",
            "path": "/covers/1.jpg",
            "originalName": "1.jpg"
          },
          "totalViews": 100,
          "totalLikes": 50,
          "likesCount": 50,
          "pagesCount": 10,
          "epsCount": 3,
          "finished": true,
          "categories": ["A", "B"],
          "tags": ["tag1"]
        }
        """
        let comic = try decode(json)
        XCTAssertEqual(comic.id, "comic-1")
        XCTAssertEqual(comic.title, "Title")
        XCTAssertEqual(comic.author, "Author")
        XCTAssertEqual(comic.totalViews, 100)
        XCTAssertEqual(comic.totalLikes, 50)
        XCTAssertEqual(comic.likesCount, 50)
        XCTAssertEqual(comic.pagesCount, 10)
        XCTAssertEqual(comic.epsCount, 3)
        XCTAssertTrue(comic.finished)
        XCTAssertEqual(comic.categories, ["A", "B"])
        XCTAssertEqual(comic.tags, ["tag1"])
    }

    func testLossyIntAcceptsStringNumbers() throws {
        let json = """
        {
          "_id": "comic-2",
          "title": "T",
          "totalViews": "42",
          "likesCount": "7",
          "pagesCount": "3",
          "epsCount": "1"
        }
        """
        let comic = try decode(json)
        XCTAssertEqual(comic.totalViews, 42)
        XCTAssertEqual(comic.likesCount, 7)
        XCTAssertEqual(comic.pagesCount, 3)
        XCTAssertEqual(comic.epsCount, 1)
    }

    func testMissingFieldsFallBackToDefaults() throws {
        let json = """
        { "_id": "comic-3", "title": "Only Title" }
        """
        let comic = try decode(json)
        XCTAssertEqual(comic.id, "comic-3")
        XCTAssertEqual(comic.title, "Only Title")
        XCTAssertEqual(comic.author, "")
        XCTAssertEqual(comic.totalViews, 0)
        XCTAssertNil(comic.totalLikes)
        XCTAssertEqual(comic.likesCount, 0)
        XCTAssertEqual(comic.pagesCount, 0)
        XCTAssertEqual(comic.epsCount, 0)
        XCTAssertFalse(comic.finished)
        XCTAssertTrue(comic.categories.isEmpty)
        XCTAssertTrue(comic.tags.isEmpty)
    }

    func testMissingThumbUsesPlaceholder() throws {
        let json = """
        { "_id": "comic-4", "title": "No Thumb" }
        """
        let comic = try decode(json)
        XCTAssertTrue(comic.thumb.url.isEmpty)
        XCTAssertEqual(comic.thumb.fileServer, "")
    }

    func testMissingIdGeneratesFallback() throws {
        let json = """
        { "title": "No ID" }
        """
        let comic = try decode(json)
        XCTAssertFalse(comic.id.isEmpty)
        XCTAssertEqual(comic.title, "No ID")
    }
}