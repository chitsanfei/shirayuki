import Foundation
import XCTest
@testable import Shirayuki

final class AppRelativeTimeTests: XCTestCase {
    func testFormatsWholeDayDifferenceAsRelativeTime() throws {
        let referenceDate = try XCTUnwrap(AppRelativeTime.parse("2026-07-30T12:00:00Z"))

        XCTAssertEqual(
            AppRelativeTime.string(
                from: "2026-07-27T12:00:00Z",
                relativeTo: referenceDate,
                locale: Locale(identifier: "en_US")
            ),
            "3 days ago"
        )
    }

    func testParsesFractionalAndDateOnlyAPIValues() {
        XCTAssertNotNil(AppRelativeTime.parse("2026-07-29T16:47:58.325Z"))
        XCTAssertNotNil(AppRelativeTime.parse("2026-07-29"))
        XCTAssertEqual(AppRelativeTime.string(from: ""), "—")
    }
}
