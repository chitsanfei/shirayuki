import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Anthropic Messages API-compatible transport.
actor AnthropicAgentTransport: AgentLLMTransport {
    private let configuration: AgentLLMTransportConfiguration

    init(configuration: AgentLLMTransportConfiguration) {
        self.configuration = configuration
    }

    func complete(_ request: AgentTransportRequest) async throws -> AgentAssistantEnvelope {
        guard !configuration.model.isEmpty,
              !configuration.apiKey.isEmpty,
              let origin = LLMOrigin(configuration.endpoint),
              origin.scheme == "https" else {
            throw OpenAITransportError(code: .configurationRequired)
        }
        try OpenAIAgentTransport.validateImages(request.messages)
        let bodyData = try Self.encodedRequest(model: configuration.model, request: request)

        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = bodyData

        let delegate = OpenAIOriginPinningDelegate(origin: origin)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw OpenAITransportError(code: .networkFailed)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAITransportError(code: .invalidResponse)
        }
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw OpenAITransportError(code: .unauthorized)
        case let status where OpenAIAgentTransport.isVisionCapabilityRejection(
            statusCode: status,
            containsImage: request.messages.contains { message in
                if case .transientImage = message { return true }
                return false
            }
        ):
            throw OpenAITransportError(code: .visionUnsupported)
        default:
            throw OpenAITransportError(code: .serverError)
        }

        return try Self.decodeResponse(data)
    }

    nonisolated static func encodedRequest(
        model: String,
        request: AgentTransportRequest
    ) throws -> Data {
        do {
            let payload = try AnthropicWireRequest.make(model: model, request: request)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            return try encoder.encode(payload)
        } catch let error as OpenAITransportError {
            throw error
        } catch {
            throw OpenAITransportError(code: .decodingFailed)
        }
    }

    nonisolated static func decodeResponse(_ data: Data) throws -> AgentAssistantEnvelope {
        do {
            let response = try JSONDecoder().decode(AnthropicWireResponse.self, from: data)
            let text = response.content.compactMap { block in
                block.type == "text" ? block.text : nil
            }.joined(separator: "\n")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let calls = try response.content.compactMap { block -> AgentLLMToolCall? in
                guard block.type == "tool_use",
                      let id = block.id,
                      let name = block.name,
                      let input = block.input else { return nil }
                return AgentLLMToolCall(
                    id: id,
                    name: name,
                    arguments: String(decoding: try encoder.encode(input), as: UTF8.self)
                )
            }
            return AgentAssistantEnvelope(text: text.isEmpty ? nil : text, toolCalls: calls)
        } catch let error as OpenAITransportError {
            throw error
        } catch {
            throw OpenAITransportError(code: .decodingFailed)
        }
    }
}

nonisolated private struct AnthropicWireRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [AnthropicWireMessage]
    let tools: [AnthropicWireTool]?

    enum CodingKeys: String, CodingKey {
        case model, system, messages, tools
        case maxTokens = "max_tokens"
    }

    static func make(model: String, request: AgentTransportRequest) throws -> Self {
        var systemParts: [String] = []
        var messages: [AnthropicWireMessage] = []
        var pendingToolResults: [AnthropicWireContentBlock] = []

        func flushToolResults() {
            guard !pendingToolResults.isEmpty else { return }
            messages.append(.init(role: "user", content: pendingToolResults))
            pendingToolResults.removeAll()
        }

        for message in request.messages {
            switch message {
            case let .system(text):
                systemParts.append(text)
            case let .tool(callID, content):
                pendingToolResults.append(.toolResult(callID: callID, content: content))
            case let .user(text):
                flushToolResults()
                messages.append(.init(role: "user", content: [.text(text)]))
            case let .assistant(envelope):
                flushToolResults()
                var content: [AnthropicWireContentBlock] = []
                if let text = envelope.text, !text.isEmpty { content.append(.text(text)) }
                for call in envelope.toolCalls {
                    content.append(.toolUse(
                        id: call.id,
                        name: call.name,
                        input: try AnthropicJSONValue.object(from: call.arguments)
                    ))
                }
                messages.append(.init(role: "assistant", content: content))
            case let .transientImage(callID, prompt, jpegData):
                flushToolResults()
                messages.append(.init(
                    role: "user",
                    content: [
                        .text("Tool call \(callID): \(prompt)"),
                        .image(jpegData.base64EncodedString())
                    ]
                ))
            }
        }
        flushToolResults()

        return Self(
            model: model,
            maxTokens: 4096,
            system: systemParts.isEmpty ? nil : systemParts.joined(separator: "\n"),
            messages: messages,
            tools: request.tools.isEmpty ? nil : try request.tools.map(AnthropicWireTool.init)
        )
    }
}

nonisolated private struct AnthropicWireMessage: Encodable {
    let role: String
    let content: [AnthropicWireContentBlock]
}

nonisolated private enum AnthropicWireContentBlock: Encodable {
    case text(String)
    case toolUse(id: String, name: String, input: AnthropicJSONValue)
    case toolResult(callID: String, content: String)
    case image(String)

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, content
        case toolUseID = "tool_use_id"
        case source
    }
    enum SourceKeys: String, CodingKey { case type, mediaType = "media_type", data }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .toolUse(id, name, input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case let .toolResult(callID, content):
            try container.encode("tool_result", forKey: .type)
            try container.encode(callID, forKey: .toolUseID)
            try container.encode(content, forKey: .content)
        case let .image(data):
            try container.encode("image", forKey: .type)
            var source = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try source.encode("base64", forKey: .type)
            try source.encode("image/jpeg", forKey: .mediaType)
            try source.encode(data, forKey: .data)
        }
    }
}

nonisolated private struct AnthropicWireTool: Encodable {
    let name: String
    let description: String
    let inputSchema: AnthropicJSONValue

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }

    init(_ definition: AgentToolDefinition) throws {
        name = definition.name
        description = definition.description
        inputSchema = try AnthropicJSONValue.decode(definition.parametersJSON)
    }
}

nonisolated private struct AnthropicWireResponse: Decodable {
    let content: [AnthropicResponseBlock]
}

nonisolated private struct AnthropicResponseBlock: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: AnthropicJSONValue?
}

nonisolated private enum AnthropicJSONValue: Codable, Equatable {
    case object([String: AnthropicJSONValue])
    case array([AnthropicJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    static func decode(_ source: String) throws -> Self {
        guard let data = source.data(using: .utf8) else {
            throw OpenAITransportError(code: .decodingFailed)
        }
        return try JSONDecoder().decode(Self.self, from: data)
    }

    static func object(from source: String) throws -> Self {
        let value = try decode(source)
        guard case .object = value else {
            throw OpenAITransportError(code: .decodingFailed)
        }
        return value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: Self].self) { self = .object(value) }
        else if let value = try? container.decode([Self].self) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
