import SwiftUI
import XCTest
@testable import Shirayuki

@MainActor
final class AgentUITests: XCTestCase {
    func testFloatingButtonPositionClampsInsideSafeArea() {
        let position = AgentUIState.shared.clamped(
            CGPoint(x: -100, y: 1_000),
            in: CGRect(x: 0, y: 0, width: 320, height: 640),
            safeArea: EdgeInsets(top: 44, leading: 0, bottom: 34, trailing: 0),
            buttonSize: 56
        )

        XCTAssertEqual(position.x, 36)
        XCTAssertEqual(position.y, 570)
    }
 
    func testReaderPlacementReservesToolbarZones() {
        let position = AgentUIState.shared.clamped(
            CGPoint(x: 200, y: 1_000),
            in: CGRect(x: 0, y: 0, width: 320, height: 640),
            safeArea: EdgeInsets(top: 44, leading: 0, bottom: 34, trailing: 0),
            buttonSize: 56,
            reservedTop: 64,
            reservedBottom: 190
        )

        XCTAssertEqual(position.x, 200)
        XCTAssertEqual(position.y, 380)
    }

    func testToolCallParserProducesTypedOpenComicCommand() throws {
        let parsed = try AgentToolCatalog().parse(.init(
            id: "call-1",
            name: "openComic",
            arguments: #"{"comic_id":"comic-42"}"#
        )).get()

        XCTAssertEqual(parsed.command, .openComic(comicID: "comic-42"))
    }

    func testToolCallParserRejectsUnknownAndMalformedCalls() {
        let catalog = AgentToolCatalog()
        XCTAssertEqual(
            catalog.parse(.init(id: "call-2", name: "rawHTTP", arguments: #"{"url":"https://example.com"}"#)),
            .failure(.unknownTool)
        )
        XCTAssertEqual(
            catalog.parse(.init(id: "call-3", name: "openComic", arguments: "not-json")),
            .failure(.invalidJSON)
        )
    }

    func testToolCallParserDefaultsOnlyMissingSortAndRejectsInvalidSort() throws {
        let catalog = AgentToolCatalog()
        XCTAssertEqual(
            try catalog.parse(.init(
                id: "call-missing-sort",
                name: "search",
                arguments: #"{"keyword":"comic"}"#
            )).get().command,
            .search(keyword: "comic", sort: .dd)
        )
        XCTAssertEqual(
            catalog.parse(.init(
                id: "call-invalid-sort",
                name: "search",
                arguments: #"{"keyword":"comic","sort":"not-a-sort"}"#
            )),
            .failure(.invalidValue)
        )
    }
}
