import XCTest
@testable import Shirayuki

final class AgentDomainV005Tests: XCTestCase {
    func testBlockedWordCanonicalizationAndValidation() throws {
        let composed = try BlockedWordCanonicalizer.rule(from: " Café ")
        let decomposed = try BlockedWordCanonicalizer.rule(from: "Cafe\u{301}")
        let fullWidth = try BlockedWordCanonicalizer.rule(from: "ＣＡＦＥ")

        XCTAssertEqual(composed.displayValue, "Café")
        XCTAssertEqual(composed.normalizedKey, decomposed.normalizedKey)
        XCTAssertEqual(composed.normalizedKey, fullWidth.normalizedKey)
        XCTAssertThrowsError(try BlockedWordCanonicalizer.rule(from: " \n ")) {
            XCTAssertEqual($0 as? BlockedWordValidationError, .empty)
        }
        XCTAssertThrowsError(try BlockedWordCanonicalizer.rule(from: "bad\u{7}word")) {
            XCTAssertEqual($0 as? BlockedWordValidationError, .controlCharacter)
        }
        XCTAssertNoThrow(try BlockedWordCanonicalizer.rule(from: String(repeating: "好", count: 64)))
        XCTAssertThrowsError(try BlockedWordCanonicalizer.rule(from: String(repeating: "好", count: 65))) {
            XCTAssertEqual($0 as? BlockedWordValidationError, .tooLong)
        }
    }

    func testBlockedWordMatcherChecksEveryRemoteField() throws {
        let rule = try BlockedWordCanonicalizer.rule(from: "作者")
        let snapshot = BlockedWordSnapshot(revision: 1, rules: [rule])

        XCTAssertTrue(BlockedWordMatcher.matches(fields: ["标题", "某作者名", "分类", "标签"], snapshot: snapshot))
        XCTAssertFalse(BlockedWordMatcher.matches(fields: ["标题", "其他", "分类", "标签"], snapshot: snapshot))
    }

    func testSessionOwnerTitleAndLimits() {
        XCTAssertEqual(AgentSessionOwner.anonymous, "anonymous")
        XCTAssertEqual(
            AgentSessionOwner.pica(userID: "user-1"),
            "pica:c6c289e49e9c05b2145860387b73bcb18df43fb09a1e4a4a9713c76c88bb541b"
        )
        XCTAssertNotEqual(AgentSessionOwner.pica(userID: "user-1"), AgentSessionOwner.pica(userID: "user-2"))
        XCTAssertEqual(AgentSessionLimits.title(from: "  " + String(repeating: "漫", count: 45)).count, 40)
        XCTAssertTrue(AgentSessionLimits.validateUserText(String(repeating: "a", count: AgentSessionLimits.maximumUserBytes)))
        XCTAssertFalse(AgentSessionLimits.validateUserText(String(repeating: "a", count: AgentSessionLimits.maximumUserBytes + 1)))
    }

    func testAssistantTruncationKeepsUnicodeBoundaries() {
        let text = String(repeating: "漫", count: 30_000)
        let bounded = AgentSessionLimits.boundedAssistantText(text, truncatedSuffix: "[truncated]")

        XCTAssertLessThanOrEqual(bounded.lengthOfBytes(using: .utf8), AgentSessionLimits.maximumAssistantBytes)
        XCTAssertTrue(bounded.hasSuffix("[truncated]"))
        XCTAssertEqual(AgentSessionLimits.boundedObservation(String(repeating: "x", count: 70_000)), "observation_too_large")
    }
}
