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

    func testAppVersionUsesInjectedMarketingVersion() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShirayukiVersion-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        let info: [String: Any] = [
            "CFBundleIdentifier": "shizukuworld.shirayuki.tests",
            "CFBundlePackageType": "BND",
            "CFBundleShortVersionString": "0.0.4"
        ]
        let infoData = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try infoData.write(to: bundleURL.appendingPathComponent("Info.plist"))
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let injectedVersion = try XCTUnwrap(
            bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        )

        XCTAssertEqual(injectedVersion, "0.0.4")
        XCTAssertEqual(SettingsViewModel.displayVersion(in: bundle), "v0.0.4")
    }

    @MainActor
    func testAgentSettingsExposeOpenAIAsTheDefaultOption() {
        let endpoint = LLMSettingsStore.defaultEndpoint.absoluteString
        XCTAssertEqual(LLMProvider.allCases.first, .openAI)
        XCTAssertEqual(endpoint, "https://api.openai.com/v1/chat/completions")
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
