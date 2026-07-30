import Foundation
import XCTest
@testable import Shirayuki

/// Verifies advanced-search payload and sort-code encoding.
final class SearchPayloadEncodingTests: XCTestCase {
    func testSearchPayloadEncodesOnlyKeywordAndSort() throws {
        let payload = SearchPayload(keyword: "猫", sort: .dd)
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["keyword"] as? String, "猫")
        XCTAssertEqual(json["sort"] as? String, ComicSortType.dd.rawValue)
        XCTAssertNil(json["page"])
        XCTAssertEqual(json.count, 2)
    }

    func testAscendingSearchMapsDateSortToAPIAscendingCode() {
        XCTAssertEqual(
            SearchViewModel.resolvedSortMode(sortMode: .dd, ascending: true),
            .da
        )
    }

    func testNonDateSearchSortRemainsStableWhenAscendingIsSelected() {
        XCTAssertEqual(
            SearchViewModel.resolvedSortMode(sortMode: .ld, ascending: true),
            .ld
        )
    }
}
