import XCTest
@testable import Shirayuki

final class ShirayukiTests: XCTestCase {
    func testReaderRouteTabMapping() {
        XCTAssertEqual(ReaderRoute.tab(for: "/"), .home)
        XCTAssertEqual(ReaderRoute.tab(for: "/categories?x=1"), .categories)
        XCTAssertEqual(ReaderRoute.tab(for: "/games"), .games)
        XCTAssertEqual(ReaderRoute.tab(for: "/profile/123"), .profile)
        XCTAssertEqual(ReaderRoute.tab(for: "/comics/search"), .search)
        XCTAssertNil(ReaderRoute.tab(for: "/unknown"))
    }

    func testReaderRouteDetection() {
        XCTAssertTrue(ReaderRoute.isReaderPath("/comic/reader/abc/1"))
        XCTAssertFalse(ReaderRoute.isReaderPath("/comic/intro/abc"))
    }

    func testStatusPriority() {
        XCTAssertEqual(ReaderRoute.status(isLoggedIn: false, isInReader: false), .notLoggedIn)
        XCTAssertEqual(ReaderRoute.status(isLoggedIn: true, isInReader: false), .loggedIn)
        XCTAssertEqual(ReaderRoute.status(isLoggedIn: false, isInReader: true), .inReader)
        XCTAssertEqual(ReaderRoute.status(isLoggedIn: true, isInReader: true), .inReader)
    }

    func testTabPathsStayStable() {
        XCTAssertEqual(ShirayukiTab.search.path, "/comics/search")
        XCTAssertEqual(ShirayukiTab.profile.path, "/profile")
    }
}
