import XCTest
@testable import Shirayuki

final class AgentToolCatalogV005Tests: XCTestCase {
    private let catalog = AgentToolCatalog()

    func testDefinitionsAndConcreteDecoderAgree() throws {
        XCTAssertEqual(catalog.definitions.count, 24)
        XCTAssertTrue(catalog.definitions.allSatisfy { $0.parametersJSON.contains(#""additionalProperties":false"#) })
        XCTAssertFalse(catalog.definitions.contains { $0.parametersJSON.contains("commandID") })

        let parsed = try catalog.parse(.init(
            id: "call-1",
            name: "startDownload",
            arguments: #"{"comic_id":"comic","chapter_ids":["one","two"],"quality":"high"}"#
        )).get()
        XCTAssertEqual(
            parsed.command,
            .startDownload(comicID: "comic", chapterIDs: ["one", "two"], quality: .high, commandID: "call-1")
        )
    }

    func testStableParserErrors() {
        XCTAssertEqual(error(name: "missing", arguments: "{}"), .unknownTool)
        XCTAssertEqual(error(name: "search", arguments: "{"), .invalidJSON)
        XCTAssertEqual(error(name: "search", arguments: #"{"keyword":"x","extra":true}"#), .unknownArgument)
        XCTAssertEqual(error(name: "search", arguments: "{}"), .missingArgument)
        XCTAssertEqual(error(name: "search", arguments: #"{"keyword":1}"#), .invalidType)
        XCTAssertEqual(error(name: "search", arguments: #"{"keyword":"x","sort":"bad"}"#), .invalidValue)
        XCTAssertEqual(error(name: "favoritePage", arguments: #"{"page":101}"#), .valueOutOfRange)
        XCTAssertEqual(
            error(name: "startDownload", arguments: #"{"comic_id":"x","chapter_ids":["a","a"],"quality":"high"}"#),
            .invalidValue
        )
    }

    func testBlockedMutationUsesEnvelopeCallID() throws {
        let parsed = try catalog.parse(.init(
            id: "blocked-call",
            name: "addBlockedWord",
            arguments: #"{"word":" Café "}"#
        )).get()
        XCTAssertEqual(parsed.command, .addBlockedWord(word: "Café", commandID: "blocked-call"))
    }

    func testIncludedMutationAndOfflineDeleteUseEnvelopeCallID() throws {
        XCTAssertEqual(
            try catalog.parse(.init(
                id: "include-call",
                name: "addIncludedWord",
                arguments: #"{"word":"Drama"}"#
            )).get().command,
            .addIncludedWord(word: "Drama", commandID: "include-call")
        )
        XCTAssertEqual(
            try catalog.parse(.init(
                id: "delete-call",
                name: "deleteOfflineComic",
                arguments: #"{"comic_id":"comic"}"#
            )).get().command,
            .deleteOfflineComic(comicID: "comic", commandID: "delete-call")
        )
    }

    private func error(name: String, arguments: String) -> AgentToolParseError? {
        guard case let .failure(error) = catalog.parse(.init(id: "call", name: name, arguments: arguments)) else {
            return nil
        }
        return error
    }
}
