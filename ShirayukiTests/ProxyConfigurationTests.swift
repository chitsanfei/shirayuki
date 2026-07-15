import XCTest
@testable import Shirayuki

final class ProxyConfigurationTests: XCTestCase {
    func testProxyRuleAcceptsHTTPHostAndPort() {
        let rule = AppProxyRule(
            id: "custom",
            name: "Local",
            urlString: "http://127.0.0.1:7890",
            isBuiltIn: false
        )

        XCTAssertEqual(rule.url?.port, 7890)
        XCTAssertEqual(rule.url?.absoluteString, "http://127.0.0.1:7890/")
    }

    func testProxyRuleRejectsInvalidSchemeAndURLParts() {
        XCTAssertNil(AppProxyRule.validURL(from: ""))
        XCTAssertNil(AppProxyRule.validURL(from: "ftp://127.0.0.1:7890"))
        XCTAssertNil(AppProxyRule.validURL(from: "https://user:pass@example.com"))
    }

    func testGo2778IsBuiltInAndFixed() {
        XCTAssertTrue(AppProxyRule.go2778.isBuiltIn)
        XCTAssertEqual(AppProxyRule.go2778.id, "go2778")
        XCTAssertEqual(AppProxyRule.go2778.urlString, "https://picaapi.go2778.com/")
    }
}
