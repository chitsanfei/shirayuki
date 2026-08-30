import Foundation
import XCTest
@testable import Shirayuki

final class AgentProviderFormatsTests: XCTestCase {
    @MainActor
    func testLegacyOpenAISettingsMigrateToDeepSeekDefaults() async throws {
        let suite = "AgentProviderMigration.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("openai", forKey: "llm_provider")
        defaults.set("", forKey: "llm_model")

        let store = LLMSettingsStore(defaults: defaults)
        XCTAssertEqual(store.provider, .openAICompatible)
        XCTAssertEqual(store.model, "deepseek-chat")
        XCTAssertEqual(store.baseURLString, "https://api.deepseek.com")
        XCTAssertNotNil(store.configuration)
        XCTAssertEqual(store.configuration?.requestURL.absoluteString, "https://api.deepseek.com/chat/completions")
    }

    @MainActor
    func testConsolidatedApplyPrivacyAndReset() async throws {
        let suite = "AgentProviderApply.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LLMSettingsStore(defaults: defaults)
        let anthropicURL = "https://anthropic.example.com/v1/messages"

        XCTAssertEqual(
            store.apply(
                provider: .anthropicCompatible,
                model: "claude-model",
                baseURL: anthropicURL,
                apiKey: ""
            ),
            .privacyConfirmationRequired(host: "anthropic.example.com")
        )
        XCTAssertEqual(
            store.apply(
                provider: .anthropicCompatible,
                model: "claude-model",
                baseURL: anthropicURL,
                apiKey: "test-secret",
                executionMode: .yolo,
                autoCompactEnabled: false,
                autoCompactThresholdKiB: 256,
                toolCallLimit: 99,
                riskAuthorizationEnabled: false,
                privacyConfirmed: true
            ),
            .applied
        )
        XCTAssertEqual(store.configuration?.provider, .anthropicCompatible)
        XCTAssertEqual(store.configuration?.model, "claude-model")
        XCTAssertEqual(store.configuration?.baseURL.absoluteString, anthropicURL)
        XCTAssertEqual(store.executionMode, .yolo)
        XCTAssertFalse(store.autoCompactEnabled)
        XCTAssertEqual(store.autoCompactThresholdKiB, 256)
        XCTAssertEqual(store.toolCallLimit, 20)
        XCTAssertFalse(store.riskAuthorizationEnabled)
        XCTAssertTrue(store.hasAPIKey)
        store.clearAPIKey()
        XCTAssertFalse(store.hasAPIKey)

        store.resetToDefaults()
        XCTAssertEqual(store.configuration?.requestURL.absoluteString, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(store.provider, .openAICompatible)
        XCTAssertEqual(store.model, "deepseek-chat")
        XCTAssertEqual(store.executionMode, .ask)
        XCTAssertTrue(store.autoCompactEnabled)
        XCTAssertEqual(store.autoCompactThresholdKiB, 128)
        XCTAssertEqual(store.toolCallLimit, 10)
        XCTAssertTrue(store.riskAuthorizationEnabled)
        XCTAssertEqual(store.baseURLString, LLMSettingsStore.defaultEndpoint.absoluteString)
    }

    func testProviderBaseURLsNormalizeToWireEndpoints() throws {
        XCTAssertEqual(
            LLMSettingsStore.requestEndpoint(
                provider: .openAICompatible,
                baseURL: try XCTUnwrap(URL(string: "https://api.deepseek.com"))
            ).absoluteString,
            "https://api.deepseek.com/chat/completions"
        )
        XCTAssertEqual(
            LLMSettingsStore.requestEndpoint(
                provider: .openAICompatible,
                baseURL: try XCTUnwrap(URL(string: "https://provider.example/v1"))
            ).absoluteString,
            "https://provider.example/v1/chat/completions"
        )
        XCTAssertEqual(
            LLMSettingsStore.requestEndpoint(
                provider: .openAICompatible,
                baseURL: try XCTUnwrap(URL(string: "https://provider.example/v1/responses"))
            ).absoluteString,
            "https://provider.example/v1/responses"
        )
        XCTAssertEqual(
            LLMSettingsStore.requestEndpoint(
                provider: .anthropicCompatible,
                baseURL: try XCTUnwrap(URL(string: "https://api.anthropic.com"))
            ).absoluteString,
            "https://api.anthropic.com/v1/messages"
        )
        XCTAssertEqual(
            LLMSettingsStore.requestEndpoint(
                provider: .anthropicCompatible,
                baseURL: try XCTUnwrap(URL(string: "https://api.anthropic.com/v1/messages"))
            ).absoluteString,
            "https://api.anthropic.com/v1/messages"
        )
    }

    func testOpenAIResponsesWireEncodingAndDecoding() throws {
        let endpoint = try XCTUnwrap(URL(string: "https://provider.example/v1/responses"))
        let request = AgentTransportRequest(
            messages: [
                .system("system"),
                .assistant(.init(
                    text: "working",
                    toolCalls: [.init(id: "call-1", name: "currentContext", arguments: "{}")]
                )),
                .tool(callID: "call-1", content: "ok"),
                .transientImage(
                    callID: "call-image",
                    prompt: "page",
                    jpegData: Data([0xFF, 0xD8, 0xFF, 0xD9])
                )
            ],
            tools: AgentToolCatalog().definitions
        )

        let encoded = try OpenAIAgentTransport.encodedRequest(
            model: "gpt-model",
            request: request,
            endpoint: endpoint
        )
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertTrue(text.contains(#""input""#))
        XCTAssertTrue(text.contains(#""type":"function_call""#))
        XCTAssertTrue(text.contains(#""type":"function_call_output""#))
        XCTAssertTrue(text.contains(#""type":"input_image""#))
        XCTAssertTrue(text.contains(#""parallel_tool_calls":false"#))
        XCTAssertFalse(text.contains(#""messages""#))
        XCTAssertFalse(text.contains(#""temperature""#))
        XCTAssertFalse(text.contains(#""function":{"#))

        let response = Data(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"done"}]},{"type":"function_call","id":"fc_1","call_id":"call-2","name":"search","arguments":"{\"keyword\":\"comic\"}"}]}"#.utf8)
        let envelope = try OpenAIAgentTransport.decodeResponse(response, endpoint: endpoint)
        XCTAssertEqual(envelope.text, "done")
        XCTAssertEqual(
            envelope.toolCalls,
            [.init(id: "call-2", name: "search", arguments: #"{"keyword":"comic"}"#)]
        )
    }

    func testAnthropicWireEncodingAndResponseDecoding() throws {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let request = AgentTransportRequest(
            messages: [
                .system("system"),
                .assistant(.init(
                    text: "thinking complete",
                    toolCalls: [.init(id: "call-1", name: "currentContext", arguments: "{}")]
                )),
                .tool(callID: "call-1", content: "ok"),
                .transientImage(callID: "call-2", prompt: "page", jpegData: jpeg)
            ],
            tools: AgentToolCatalog().definitions
        )
        let encoded = try AnthropicAgentTransport.encodedRequest(model: "claude-model", request: request)
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertTrue(text.contains(#""max_tokens":4096"#))
        XCTAssertTrue(text.contains(#""type":"tool_use""#))
        XCTAssertTrue(text.contains(#""type":"tool_result""#))
        XCTAssertTrue(text.contains(#""input_schema""#))
        XCTAssertTrue(text.contains(#""media_type":"image/jpeg""#))

        let response = Data(#"{"content":[{"type":"text","text":"done"},{"type":"tool_use","id":"call-2","name":"search","input":{"keyword":"comic"}}]}"#.utf8)
        let envelope = try AnthropicAgentTransport.decodeResponse(response)
        XCTAssertEqual(envelope.text, "done")
        XCTAssertEqual(envelope.toolCalls.count, 1)
        XCTAssertEqual(envelope.toolCalls.first?.id, "call-2")
        XCTAssertEqual(envelope.toolCalls.first?.name, "search")
        XCTAssertEqual(envelope.toolCalls.first?.arguments, #"{"keyword":"comic"}"#)
    }
}
