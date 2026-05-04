import XCTest
@testable import Shirayuki

final class RoutingAndSettingsTests: XCTestCase {
    func testCategorySourceDerivesIdentifiersAndMessages() {
        let source = ComicsBrowserSource.category("恋爱")

        XCTAssertEqual(source.id, "category:恋爱")
        XCTAssertEqual(source.title, "恋爱")
        XCTAssertEqual(source.emptyTitle, "暂无漫画")
        XCTAssertEqual(source.emptySubtitle, "恋爱 分类里还没有可显示的内容")
    }

    func testAPIEndpointsExposeReadableDescriptions() {
        XCTAssertEqual(APIEndpoint.picacomic.displayName, "Picacomic 官方")
        XCTAssertFalse(APIEndpoint.picacomic.description.isEmpty)
        XCTAssertEqual(APIEndpoint.go2778.displayName, "Go2778 代理")
        XCTAssertFalse(APIEndpoint.go2778.description.isEmpty)
    }

    @MainActor
    func testThirdPartyNoticesDescribeDesignReferences() {
        let previousLanguage = AppLocalization.shared.language
        AppLocalization.shared.setLanguage(.simplifiedChinese)
        defer { AppLocalization.shared.setLanguage(previousLanguage) }

        let text = SettingsViewModel().thirdPartyNoticesText

        XCTAssertTrue(text.contains("haka_comic"))
        XCTAssertTrue(text.contains("design guidance only"))
        XCTAssertTrue(text.contains("Liquid Glass"))
    }
}
