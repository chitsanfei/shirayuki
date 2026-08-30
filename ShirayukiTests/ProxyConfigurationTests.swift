import XCTest
@testable import Shirayuki

/// Verifies route validation, ordering, editability, and host replacement.
@MainActor
final class ProxyConfigurationTests: XCTestCase {
    func testOfficialRouteIsFixed() {
        XCTAssertEqual(AppProxyRule.official.id, "picacomic")
        XCTAssertEqual(AppProxyRule.official.urlString, "https://picaapi.picacomic.com/")
        XCTAssertTrue(AppProxyRule.official.isOfficial)
        XCTAssertFalse(AppProxyRule.official.isEditable)
        XCTAssertFalse(AppProxyRule.official.canDelete)
    }

    func testBundledRoutesIncludeFixedGo2778() throws {
        let route = try XCTUnwrap(
            AppProxyRule.loadBundledRules().first(where: { $0.id == "go2778" })
        )

        XCTAssertEqual(route.urlString, "https://picaapi.go2778.com/")
        XCTAssertEqual(route.source, .bundled)
        XCTAssertFalse(route.isEditable)
        XCTAssertFalse(route.canDelete)
        XCTAssertEqual(
            route.imageURL(for: "https://storage.picacomic.com/static/example.jpg"),
            "https://storage.go2778.com/static/example.jpg"
        )
    }

    func testBundledRouteDefinitionControlsEditing() throws {
        let data = Data(
            """
            [{
              "id": "community",
              "name": "Community",
              "urlString": "https://api.example.com",
              "isEditable": true
            }]
            """.utf8
        )

        let route = try XCTUnwrap(AppProxyRule.decodeBundledRules(from: data).first)
        XCTAssertEqual(route.urlString, "https://api.example.com/")
        XCTAssertTrue(route.isEditable)
        XCTAssertFalse(route.canDelete)
    }

    func testProxyRuleAcceptsHTTPHostAndPort() {
        let rule = AppProxyRule(
            id: "custom",
            name: "Local",
            urlString: "http://127.0.0.1:7890",
            source: .user,
            isEditable: true
        )

        XCTAssertEqual(rule.url?.port, 7890)
        XCTAssertEqual(rule.url?.absoluteString, "http://127.0.0.1:7890/")
    }

    func testProxyRuleRejectsInvalidSchemeAndURLParts() {
        XCTAssertNil(AppProxyRule.validURL(from: ""))
        XCTAssertNil(AppProxyRule.validURL(from: "ftp://127.0.0.1:7890"))
        XCTAssertNil(AppProxyRule.validURL(from: "https://user:pass@example.com"))
    }
    func testOfficialRoutePrecedesBundledRoutes() {
        let routes = [AppProxyRule.official] + AppProxyRule.loadBundledRules()

        XCTAssertEqual(routes.first?.id, AppProxyRule.official.id)
        XCTAssertEqual(routes.dropFirst().first?.id, "go2778")
    }

}
