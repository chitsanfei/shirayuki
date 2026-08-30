import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated struct AgentLLMTransportConfiguration: Equatable, Sendable {
    let endpoint: URL
    let model: String
    let apiKey: String
}

actor OpenAIAgentTransport: AgentLLMTransport {
    private enum WireFormat {
        case chatCompletions
        case responses
    }

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
        try Self.validateImages(request.messages)
        let bodyData = try Self.encodedRequest(
            model: configuration.model,
            request: request,
            endpoint: configuration.endpoint
        )

        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
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
        case let status where Self.isVisionCapabilityRejection(
            statusCode: status,
            containsImage: request.messages.contains(where: \AgentTransportMessage.containsImage)
        ):
            throw OpenAITransportError(code: .visionUnsupported)
        default:
            throw OpenAITransportError(code: .serverError)
        }

        return try Self.decodeResponse(data, endpoint: configuration.endpoint)
    }

    nonisolated static func encodedRequest(
        model: String,
        request: AgentTransportRequest
    ) throws -> Data {
        try encodedRequest(
            model: model,
            request: request,
            format: .chatCompletions
        )
    }

    nonisolated static func encodedRequest(
        model: String,
        request: AgentTransportRequest,
        endpoint: URL
    ) throws -> Data {
        try encodedRequest(model: model, request: request, format: wireFormat(for: endpoint))
    }

    nonisolated static func decodeResponse(
        _ data: Data,
        endpoint: URL
    ) throws -> AgentAssistantEnvelope {
        switch wireFormat(for: endpoint) {
        case .chatCompletions:
            if let value = try? decodeChatCompletion(data) { return value }
            return try decodeResponses(data)
        case .responses:
            if let value = try? decodeResponses(data) { return value }
            return try decodeChatCompletion(data)
        }
    }

    nonisolated static func validateImages(_ messages: [AgentTransportMessage]) throws {
        let images = messages.compactMap { message -> Data? in
            guard case let .transientImage(_, _, data) = message else { return nil }
            return data
        }
        guard images.count <= 1,
              images.allSatisfy({
                  $0.count >= 4
                      && $0.count <= AgentImageBudget.maxEncodedBytes
                      && $0.starts(with: [0xFF, 0xD8])
                      && $0.suffix(2) == [0xFF, 0xD9]
              }) else {
            throw OpenAITransportError(code: .invalidImage)
        }
    }

    nonisolated static func isVisionCapabilityRejection(
        statusCode: Int,
        containsImage: Bool
    ) -> Bool {
        containsImage && (statusCode == 400 || statusCode == 422)
    }

    nonisolated private static func wireFormat(for endpoint: URL) -> WireFormat {
        endpoint.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
            .hasSuffix("responses") ? .responses : .chatCompletions
    }

    nonisolated private static func encodedRequest(
        model: String,
        request: AgentTransportRequest,
        format: WireFormat
    ) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            switch format {
            case .chatCompletions:
                return try encoder.encode(OpenAIWireRequest(
                    model: model,
                    messages: request.messages.map(OpenAIWireMessage.init),
                    tools: request.tools.isEmpty ? nil : request.tools.map { try OpenAIWireTool($0) },
                    parallelToolCalls: false,
                    temperature: 0.2
                ))
            case .responses:
                return try encoder.encode(OpenAIResponsesWireRequest(
                    model: model,
                    input: request.messages.flatMap(OpenAIResponsesInputItem.items),
                    tools: request.tools.isEmpty ? nil : request.tools.map { try OpenAIResponsesTool($0) },
                    parallelToolCalls: false,
                    store: false
                ))
            }
        } catch let error as OpenAITransportError {
            throw error
        } catch {
            throw OpenAITransportError(code: .decodingFailed)
        }
    }

    nonisolated private static func decodeChatCompletion(
        _ data: Data
    ) throws -> AgentAssistantEnvelope {
        guard let message = try JSONDecoder()
            .decode(OpenAIWireCompletion.self, from: data)
            .choices.first?.message else {
            throw OpenAITransportError(code: .invalidResponse)
        }
        return AgentAssistantEnvelope(
            text: message.content,
            toolCalls: message.toolCalls?.map {
                AgentLLMToolCall(
                    id: $0.id,
                    name: $0.function.name,
                    arguments: $0.function.arguments
                )
            } ?? []
        )
    }

    nonisolated private static func decodeResponses(
        _ data: Data
    ) throws -> AgentAssistantEnvelope {
        do {
            let response = try JSONDecoder().decode(OpenAIResponsesWireResponse.self, from: data)
            let text = ([response.outputText] + response.output.flatMap(\.textValues))
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            let calls = response.output.compactMap(\.toolCall)
            guard !text.isEmpty || !calls.isEmpty else {
                throw OpenAITransportError(code: .invalidResponse)
            }
            return AgentAssistantEnvelope(
                text: text.isEmpty ? nil : text,
                toolCalls: calls
            )
        } catch let error as OpenAITransportError {
            throw error
        } catch {
            throw OpenAITransportError(code: .decodingFailed)
        }
    }
}

nonisolated private extension AgentTransportMessage {
    var containsImage: Bool {
        if case .transientImage = self { return true }
        return false
    }
}

nonisolated private struct OpenAIWireRequest: Encodable {
    let model: String
    let messages: [OpenAIWireMessage]
    let tools: [OpenAIWireTool]?
    let parallelToolCalls: Bool
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, temperature
        case parallelToolCalls = "parallel_tool_calls"
    }
}

nonisolated private struct OpenAIWireMessage: Encodable {
    let role: String
    let content: OpenAIWireContent?
    let toolCalls: [OpenAIWireToolCall]?
    let toolCallID: String?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallID = "tool_call_id"
    }

    init(_ message: AgentTransportMessage) {
        switch message {
        case let .system(text):
            role = "system"; content = .text(text); toolCalls = nil; toolCallID = nil
        case let .user(text):
            role = "user"; content = .text(text); toolCalls = nil; toolCallID = nil
        case let .assistant(envelope):
            role = "assistant"
            content = envelope.text.map(OpenAIWireContent.text)
            toolCalls = envelope.toolCalls.map(OpenAIWireToolCall.init)
            toolCallID = nil
        case let .tool(callID, text):
            role = "tool"; content = .text(text); toolCalls = nil; toolCallID = callID
        case let .transientImage(callID, prompt, jpegData):
            role = "user"
            content = .parts([
                .text("Tool call \(callID): \(prompt)"),
                .imageURL("data:image/jpeg;base64,\(jpegData.base64EncodedString())")
            ])
            toolCalls = nil
            toolCallID = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        if let content { try container.encode(content, forKey: .content) }
        if let toolCalls, !toolCalls.isEmpty { try container.encode(toolCalls, forKey: .toolCalls) }
        if let toolCallID { try container.encode(toolCallID, forKey: .toolCallID) }
    }
}

nonisolated private enum OpenAIWireContent: Encodable {
    case text(String)
    case parts([OpenAIWireContentPart])

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .parts(parts):
            var container = encoder.singleValueContainer()
            try container.encode(parts)
        }
    }
}

nonisolated private enum OpenAIWireContentPart: Encodable {
    case text(String)
    case imageURL(String)

    enum CodingKeys: String, CodingKey { case type, text, imageURL = "image_url" }
    enum ImageKeys: String, CodingKey { case url }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .imageURL(url):
            try container.encode("image_url", forKey: .type)
            var image = container.nestedContainer(keyedBy: ImageKeys.self, forKey: .imageURL)
            try image.encode(url, forKey: .url)
        }
    }
}

nonisolated private struct OpenAIWireToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAIWireFunctionCall

    init(_ call: AgentLLMToolCall) {
        id = call.id
        type = "function"
        function = OpenAIWireFunctionCall(name: call.name, arguments: call.arguments)
    }
}

nonisolated private struct OpenAIWireFunctionCall: Codable {
    let name: String
    let arguments: String
}

nonisolated private struct OpenAIWireTool: Encodable {
    let type = "function"
    let function: OpenAIWireToolFunction

    init(_ definition: AgentToolDefinition) throws {
        guard let data = definition.parametersJSON.data(using: .utf8) else {
            throw OpenAITransportError(code: .decodingFailed)
        }
        function = OpenAIWireToolFunction(
            name: definition.name,
            description: definition.description,
            parameters: try JSONDecoder().decode(OpenAIWireJSONValue.self, from: data)
        )
    }
}

nonisolated private struct OpenAIWireToolFunction: Encodable {
    let name: String
    let description: String
    let parameters: OpenAIWireJSONValue
}

nonisolated private enum OpenAIWireJSONValue: Codable {
    case object([String: OpenAIWireJSONValue])
    case array([OpenAIWireJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: OpenAIWireJSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([OpenAIWireJSONValue].self) { self = .array(value) }
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

nonisolated private struct OpenAIWireCompletion: Decodable {
    let choices: [OpenAIWireChoice]
}

nonisolated private struct OpenAIWireChoice: Decodable {
    let message: OpenAIWireResponseMessage
}

nonisolated private struct OpenAIWireResponseMessage: Decodable {
    let content: String?
    let toolCalls: [OpenAIWireToolCall]?

    enum CodingKeys: String, CodingKey {
        case content
        case toolCalls = "tool_calls"
    }
}

nonisolated private struct OpenAIResponsesWireRequest: Encodable {
    let model: String
    let input: [OpenAIResponsesInputItem]
    let tools: [OpenAIResponsesTool]?
    let parallelToolCalls: Bool
    let store: Bool

    enum CodingKeys: String, CodingKey {
        case model, input, tools, store
        case parallelToolCalls = "parallel_tool_calls"
    }
}

nonisolated private enum OpenAIResponsesInputItem: Encodable {
    case message(role: String, content: OpenAIResponsesContent)
    case functionCall(id: String, name: String, arguments: String)
    case functionOutput(id: String, output: String)

    enum CodingKeys: String, CodingKey {
        case type, role, content, name, arguments, output
        case callID = "call_id"
    }

    static func items(_ message: AgentTransportMessage) -> [Self] {
        switch message {
        case let .system(text):
            [.message(role: "system", content: .text(text))]
        case let .user(text):
            [.message(role: "user", content: .text(text))]
        case let .assistant(envelope):
            (envelope.text.map {
                [.message(role: "assistant", content: .text($0))]
            } ?? []) + envelope.toolCalls.map {
                .functionCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            }
        case let .tool(callID, text):
            [.functionOutput(id: callID, output: text)]
        case let .transientImage(callID, prompt, jpegData):
            [.message(role: "user", content: .parts([
                .text("Tool call \(callID): \(prompt)"),
                .image("data:image/jpeg;base64,\(jpegData.base64EncodedString())")
            ]))]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .message(role, content):
            try container.encode("message", forKey: .type)
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
        case let .functionCall(id, name, arguments):
            try container.encode("function_call", forKey: .type)
            try container.encode(id, forKey: .callID)
            try container.encode(name, forKey: .name)
            try container.encode(arguments, forKey: .arguments)
        case let .functionOutput(id, output):
            try container.encode("function_call_output", forKey: .type)
            try container.encode(id, forKey: .callID)
            try container.encode(output, forKey: .output)
        }
    }
}

nonisolated private enum OpenAIResponsesContent: Encodable {
    case text(String)
    case parts([OpenAIResponsesContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(text): try container.encode(text)
        case let .parts(parts): try container.encode(parts)
        }
    }
}

nonisolated private enum OpenAIResponsesContentPart: Encodable {
    case text(String)
    case image(String)

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .image(url):
            try container.encode("input_image", forKey: .type)
            try container.encode(url, forKey: .imageURL)
        }
    }
}

nonisolated private struct OpenAIResponsesTool: Encodable {
    let type = "function"
    let name: String
    let description: String
    let parameters: OpenAIWireJSONValue

    init(_ definition: AgentToolDefinition) throws {
        guard let data = definition.parametersJSON.data(using: .utf8) else {
            throw OpenAITransportError(code: .decodingFailed)
        }
        name = definition.name
        description = definition.description
        parameters = try JSONDecoder().decode(OpenAIWireJSONValue.self, from: data)
    }
}

nonisolated private struct OpenAIResponsesWireResponse: Decodable {
    let outputText: String?
    let output: [OpenAIResponsesOutputItem]

    enum CodingKeys: String, CodingKey {
        case output
        case outputText = "output_text"
    }
}

nonisolated private struct OpenAIResponsesOutputItem: Decodable {
    let id: String?
    let type: String
    let callID: String?
    let name: String?
    let arguments: String?
    let content: [OpenAIResponsesOutputContent]?

    enum CodingKeys: String, CodingKey {
        case id, type, name, arguments, content
        case callID = "call_id"
    }

    var textValues: [String?] {
        guard type == "message" else { return [] }
        return content?.map(\.text) ?? []
    }

    var toolCall: AgentLLMToolCall? {
        guard type == "function_call",
              let id = callID ?? id,
              let name,
              let arguments else { return nil }
        return AgentLLMToolCall(id: id, name: name, arguments: arguments)
    }
}

nonisolated private struct OpenAIResponsesOutputContent: Decodable {
    let type: String
    let text: String?
}
