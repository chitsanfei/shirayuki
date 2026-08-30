import Foundation
import XCTest
@testable import Shirayuki

final class AgentPageContentTests: XCTestCase {
    func testVisibleComicListProjectionIsBounded() throws {
        let comics = try (0..<15).map(makeSummary)
        let content = PicaAgentAdapters.pageContent(
            source: "home.weekly",
            title: "Weekly",
            comics: comics
        )
        guard case let .comicList(source, title, items, totalVisible) = content else {
            return XCTFail("Expected list content")
        }
        XCTAssertEqual(source, "home.weekly")
        XCTAssertEqual(title, "Weekly")
        XCTAssertEqual(totalVisible, 15)
        XCTAssertEqual(items.count, 12)

        let projection = try XCTUnwrap(AgentResultProjector.project(
            .context(.init(
                isLoggedIn: true,
                page: .init(kind: .tab, title: "Weekly", comicID: nil, chapterID: nil),
                reader: nil,
                pageContent: content
            )),
            for: .currentContext
        ))
        XCTAssertTrue(projection.contains("visiblePageSource=home.weekly"))
        XCTAssertTrue(projection.contains("Comic 0"))
        XCTAssertFalse(projection.contains("Comic 14"))
    }

    func testComicDetailProjectionIncludesDescriptionAndRecommendations() throws {
        let recommendation = AgentVisibleComicItem(
            comicID: "recommendation",
            title: "Recommended",
            author: "Author",
            categories: ["Category"],
            tags: ["Tag"],
            chapterCount: 3,
            finished: false
        )
        let detail = AgentComicDetailSnapshot(
            comicID: "detail",
            title: "Detail Comic",
            author: "Detail Author",
            summary: "Detailed description",
            categories: ["Drama"],
            tags: ["Story"],
            chapterCount: 10,
            pageCount: 200,
            totalViews: 1000,
            likesCount: 50,
            finished: true,
            isLiked: true,
            isFavorited: false,
            recommendations: [recommendation]
        )
        let projection = try XCTUnwrap(AgentResultProjector.project(
            .context(.init(
                isLoggedIn: true,
                page: .init(kind: .detail, title: detail.title, comicID: detail.comicID, chapterID: nil),
                reader: nil,
                pageContent: .comicDetail(detail)
            )),
            for: .currentContext
        ))
        XCTAssertTrue(projection.contains("Detailed description"))
        XCTAssertTrue(projection.contains("detailCategories=Drama"))
        XCTAssertTrue(projection.contains("Recommended"))
    }

    @MainActor
    func testPublishedVisibleComicIDsAuthorizeAgentOpen() async {
        let pageContent = AgentPageContentStore()
        let ownerID = UUID()
        pageContent.publish(.comicList(
            source: "home.latest",
            title: "Latest",
            items: [.init(
                comicID: "visible-comic",
                title: "Visible",
                author: "Author",
                categories: [],
                tags: [],
                chapterCount: 1,
                finished: false
            )],
            totalVisible: 1
        ), ownerID: ownerID)
        let navigation = AppNavigationCoordinator.shared
        navigation.resetForTesting()
        defer { navigation.resetForTesting() }
        let service = AgentCommandService(
            navigation: navigation,
            pageContent: pageContent,
            sessionIsLoggedIn: { true }
        )
        let sessionID = UUID()

        _ = await service.execute(.currentContext, sessionID: sessionID)
        let result = await service.execute(
            .openComic(comicID: "visible-comic"),
            sessionID: sessionID
        )
        XCTAssertEqual(result, .openedComic(comicID: "visible-comic"))
        pageContent.clear(ownerID: UUID())
        XCTAssertNotEqual(pageContent.snapshot, .unavailable)
        pageContent.clear(ownerID: ownerID)
        XCTAssertEqual(pageContent.snapshot, .unavailable)
    }

    private func makeSummary(_ index: Int) throws -> ComicSummary {
        let data = Data(
            """
            {
              "_id": "comic-\(index)",
              "title": "Comic \(index)",
              "author": "Author \(index)",
              "thumb": {},
              "epsCount": \(index + 1),
              "categories": ["Category"],
              "tags": ["Tag"]
            }
            """.utf8
        )
        return try JSONDecoder().decode(ComicSummary.self, from: data)
    }
}
