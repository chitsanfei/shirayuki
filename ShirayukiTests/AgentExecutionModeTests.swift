import Foundation
import XCTest
@testable import Shirayuki

final class AgentExecutionModeTests: XCTestCase {
    @MainActor
    func testCurrentPageOutsideReaderReturnsObservationInsteadOfRepeatedConfirmation() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://api.deepseek.com"))
        let configuration = LLMConfiguration(
            provider: .openAICompatible,
            model: "deepseek-chat",
            baseURL: baseURL,
            requestURL: LLMSettingsStore.requestEndpoint(
                provider: .openAICompatible,
                baseURL: baseURL
            ),
            keyAccount: "test"
        )
        let service = AgentCommandService(
            sessionIsLoggedIn: { true },
            llmConfiguration: { configuration },
            llmHasAPIKey: { true }
        )
        let executor = AgentCommandLoopExecutor(service: service, executionMode: { .ask })

        let execution = await executor.execute(
            .currentPageContent,
            sessionID: UUID(),
            turnID: "turn",
            confirmed: false
        )
        guard case let .observation(code, image) = execution else {
            return XCTFail("Expected context observation")
        }
        XCTAssertEqual(code, "context_unavailable")
        XCTAssertNil(image)
    }

    @MainActor
    func testYOLOAutoExecutesSideEffectsWhileAskSuspends() async throws {
        let suite = "AgentExecutionMode.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsBlockedWordRepository(defaults: defaults)
        let service = AgentCommandService(
            blockedWords: repository,
            sessionIsLoggedIn: { true }
        )
        let sessionID = UUID()

        let ask = AgentCommandLoopExecutor(service: service, executionMode: { .ask })
        let askResult = await ask.execute(
            .addBlockedWord(word: "ask-word", commandID: "ask-call"),
            sessionID: sessionID,
            turnID: "ask-turn",
            confirmed: false
        )
        guard case .confirmation(.blockedWordAdd) = askResult else {
            return XCTFail("Ask mode must suspend")
        }

        let yolo = AgentCommandLoopExecutor(service: service, executionMode: { .yolo })
        let yoloResult = await yolo.execute(
            .addBlockedWord(word: "yolo-word", commandID: "yolo-call"),
            sessionID: sessionID,
            turnID: "yolo-turn",
            confirmed: false
        )
        guard case let .observation(content, image) = yoloResult else {
            return XCTFail("YOLO mode must execute")
        }
        XCTAssertTrue(content.contains("yolo-word"))
        XCTAssertNil(image)
        let snapshot = await repository.snapshot()
        XCTAssertEqual(snapshot.revision, 1)
    }
}
