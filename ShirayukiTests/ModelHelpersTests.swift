import SwiftUI
import XCTest
@testable import Shirayuki

final class ModelHelpersTests: XCTestCase {
    func testImageDetailBuildsStaticURLWhenMissingSegment() {
        let detail = ImageDetail(
            fileServer: "https://storage1.picacomic.com",
            path: "/abc/cover.jpg",
            originalName: "cover.jpg"
        )

        XCTAssertEqual(detail.url, "https://storage1.picacomic.com/static/abc/cover.jpg")
    }

    func testImageDetailKeepsExistingStaticURL() {
        let detail = ImageDetail(
            fileServer: "https://storage1.picacomic.com/static",
            path: "/abc/cover.jpg",
            originalName: "cover.jpg"
        )

        XCTAssertEqual(detail.url, "https://storage1.picacomic.com/static/abc/cover.jpg")
    }

    func testFavoritesSourceCopyMatchesExpectedStrings() {
        XCTAssertEqual(ComicsBrowserSource.favorites.title, "我的收藏")
        XCTAssertEqual(ComicsBrowserSource.favorites.emptyTitle, "暂无收藏")
        XCTAssertEqual(ComicsBrowserSource.favorites.emptySubtitle, "收藏漫画后会在这里完整显示")
    }

    func testThemeModesMapToExpectedColorScheme() {
        XCTAssertNil(AppThemeMode.system.colorScheme)
        XCTAssertEqual(AppThemeMode.light.colorScheme, .light)
        XCTAssertEqual(AppThemeMode.dark.colorScheme, .dark)
    }
}
