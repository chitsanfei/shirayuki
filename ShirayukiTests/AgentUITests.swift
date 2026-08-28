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

    func testToolCallParserProducesTypedOpenComicCommand() {
        let call = OpenAIToolCall(
            id: "call-1",
            function: OpenAIFunctionCall(
                name: "openComic",
                arguments: #"{"comic_id":"comic-42"}"#
            )
        )

        XCTAssertEqual(
            AgentToolCallParser.command(from: call),
            .openComic(comicID: "comic-42")
        )
    }

    func testToolCallParserRejectsUnknownAndMalformedCalls() {
        let unknown = OpenAIToolCall(
            id: "call-2",
            function: OpenAIFunctionCall(name: "rawHTTP", arguments: #"{"url":"https://example.com"}"#)
        )
        let malformed = OpenAIToolCall(
            id: "call-3",
            function: OpenAIFunctionCall(name: "openComic", arguments: "not-json")
        )

        XCTAssertNil(AgentToolCallParser.command(from: unknown))
        XCTAssertNil(AgentToolCallParser.command(from: malformed))
    }
 
    func testToolCallParserDefaultsOnlyMissingSortAndRejectsInvalidSort() {
        let missing = OpenAIToolCall(
            id: "call-missing-sort",
            function: OpenAIFunctionCall(name: "search", arguments: #"{"keyword":"comic"}"#)
        )
        let invalid = OpenAIToolCall(
            id: "call-invalid-sort",
            function: OpenAIFunctionCall(name: "search", arguments: #"{"keyword":"comic","sort":"not-a-sort"}"#)
        )

        XCTAssertEqual(
            AgentToolCallParser.command(from: missing),
            .search(keyword: "comic", sort: .dd)
        )
        XCTAssertNil(AgentToolCallParser.command(from: invalid))
    }
}
