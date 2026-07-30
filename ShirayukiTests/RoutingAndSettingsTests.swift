import XCTest
@testable import Shirayuki

/// Verifies source routing metadata and settings reference text.
final class RoutingAndSettingsTests: XCTestCase {
    func testCategorySourceDerivesIdentifiersAndMessages() {
        let source = ComicsBrowserSource.category("恋爱")

        XCTAssertEqual(source.id, "category:恋爱")
        XCTAssertEqual(source.title, "恋爱")
        XCTAssertEqual(source.emptyTitle, "暂无漫画")
        XCTAssertEqual(source.emptySubtitle, "恋爱 分类里还没有可显示的内容")
    }

    func testOfficialRouteUsesReadableName() {
        XCTAssertEqual(AppProxyRule.official.displayName, "Picacomic 官方")
    }

    func testThirdPartyNoticesDescribeDesignReferences() {
        // Access the static property directly to avoid instantiating the
        // @MainActor-isolated SettingsViewModel, which triggers a Swift
        // runtime crash in its deinit under XCTest's task-local scope.
        let text = SettingsViewModel.thirdPartyNoticesText

        XCTAssertTrue(text.contains("haka_comic"))
        XCTAssertTrue(text.contains("design guidance only"))
        XCTAssertTrue(text.contains("Liquid Glass"))
    }
}
