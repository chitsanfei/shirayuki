import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
nonisolated private struct OpenAIImageURL: Encodable {
    let url: String
}

nonisolated enum OpenAIMessageContent: Codable, Sendable, Equatable {
    case text(String)
    case parts([OpenAIContentPart])

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self = .text(value)
        } else {
            self = .parts(try [OpenAIContentPart](from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .parts(values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        }
    }
}

nonisolated enum OpenAIContentPart: Codable, Sendable, Equatable {
    case text(String)
    case image(AgentImagePayload)

    private enum CodingKeys: String, CodingKey {
        case type, text, imageURL = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .text)
        case let .image(payload):
            try container.encode("image_url", forKey: .type)
            try container.encode(OpenAIImageURL(url: payload.dataURL), forKey: .imageURL)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        default:
            throw OpenAITransportError(code: .decodingFailed)
        }
    }
}

nonisolated struct OpenAIMessage: Codable, Sendable, Equatable {
    let role: String
    let content: OpenAIMessageContent

    init(role: String, content: String) {
        self.role = role
        self.content = .text(content)
    }

    init(role: String, content: OpenAIMessageContent) {
        self.role = role
        self.content = content
    }
}

nonisolated struct OpenAITool: Encodable, Sendable, Equatable {
    let type: String
    let function: OpenAIFunction

    init(name: String, description: String, parametersJSON: String) {
        type = "function"
        function = OpenAIFunction(name: name, description: description, parametersJSON: parametersJSON)
    }
}

nonisolated private enum OpenAIJSONValue: Encodable {
    case object([String: OpenAIJSONValue])
    case array([OpenAIJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(any value: Any) throws {
        if let value = value as? [String: Any] {
            self = .object(try value.mapValues(OpenAIJSONValue.init(any:)))
        } else if let value = value as? [Any] {
            self = .array(try value.map(OpenAIJSONValue.init(any:)))
        } else if let value = value as? String {
            self = .string(value)
        } else if let value = value as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .bool(value.boolValue)
            } else {
                self = .number(value.doubleValue)
            }
        } else if value is NSNull {
            self = .null
        } else {
            throw OpenAITransportError(code: .decodingFailed)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .object(values):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in values {
                try container.encode(value, forKey: DynamicCodingKey(stringValue: key)!)
            }
        case let .array(values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .number(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

nonisolated private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
    }
}

nonisolated struct OpenAIFunction: Encodable, Sendable, Equatable {
    let name: String
    let description: String
    let parametersJSON: String

    enum CodingKeys: String, CodingKey {
        case name, description, parameters
    }

    init(name: String, description: String, parametersJSON: String) {
        self.name = name
        self.description = description
        self.parametersJSON = parametersJSON
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        let json = try JSONSerialization.jsonObject(with: Data(parametersJSON.utf8))
        try container.encode(OpenAIJSONValue(any: json), forKey: .parameters)
    }
}

nonisolated private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let tools: [OpenAITool]?
    let temperature: Double
}

nonisolated struct OpenAIToolCall: Decodable, Sendable, Equatable {
    let id: String
    let function: OpenAIFunctionCall
}

nonisolated struct OpenAIFunctionCall: Decodable, Sendable, Equatable {
    let name: String
    let arguments: String
}

nonisolated struct OpenAIChoice: Decodable, Sendable, Equatable {
    let message: OpenAIResponseMessage
}

nonisolated struct OpenAIResponseMessage: Decodable, Sendable, Equatable {
    let role: String
    let content: String?
    let toolCalls: [OpenAIToolCall]?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
}

nonisolated struct OpenAICompletion: Decodable, Sendable, Equatable {
    let choices: [OpenAIChoice]

    var text: String? { choices.first?.message.content }
    var toolCalls: [OpenAIToolCall] { choices.first?.message.toolCalls ?? [] }
}

nonisolated struct OpenAITransportError: Error, Equatable, Sendable {
    enum Code: String, Sendable {
        case configurationRequired
        case invalidEndpoint
        case redirectRejected
        case invalidImage
        case visionUnsupported
        case invalidResponse
        case unauthorized
        case serverError
        case decodingFailed
        case networkFailed
    }

    let code: Code
}

nonisolated struct LLMOrigin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int

    init?(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased(),
              !scheme.isEmpty,
              !host.isEmpty else { return nil }
        self.scheme = scheme
        self.host = host
        self.port = url.port ?? (scheme == "https" ? 443 : 80)
    }

    func contains(_ url: URL) -> Bool {
        guard let other = LLMOrigin(url) else { return false }
        return self == other
    }
}

/// URLSession delegate that prevents credentials/content from crossing origins or downgrading HTTP.
final class OpenAIOriginPinningDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let origin: LLMOrigin

    init(origin: LLMOrigin) {
        self.origin = origin
    }

    static func allowsRedirect(from source: URL, to destination: URL) -> Bool {
        guard let sourceOrigin = LLMOrigin(source),
              let destinationOrigin = LLMOrigin(destination) else { return false }
        return sourceOrigin == destinationOrigin && destinationOrigin.scheme == "https"
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @Sendable @escaping (URLRequest?) -> Void
    ) {
        guard let currentURL = task.currentRequest?.url,
              let destinationURL = request.url,
              origin.contains(currentURL),
              origin.contains(destinationURL),
              Self.allowsRedirect(from: currentURL, to: destinationURL) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

/// Isolated OpenAI-compatible transport; it never touches the PicACG APIClient or token.
actor OpenAIClient {
    static let shared = OpenAIClient()

 
    private static func validateImagePayloads(in messages: [OpenAIMessage]) throws {
        var totalImageCount = 0
        for message in messages {
            guard case let .parts(parts) = message.content else { continue }
            for part in parts {
                guard case let .image(payload) = part else { continue }
                guard message.role == "user",
                      payload.jpegData.count >= 4,
                      payload.jpegData.count <= AgentImageBudget.maxEncodedBytes,
                      payload.jpegData.starts(with: [0xFF, 0xD8]),
                      payload.jpegData.suffix(2) == [0xFF, 0xD9] else {
                    throw OpenAITransportError(code: .invalidImage)
                }
                totalImageCount += 1
                guard totalImageCount <= 1 else {
                    throw OpenAITransportError(code: .invalidImage)
                }
            }
        }
    }
 
    static func isVisionCapabilityRejection(statusCode: Int, containsImage: Bool) -> Bool {
        containsImage && (statusCode == 400 || statusCode == 422)
    }

    private static func containsImage(in messages: [OpenAIMessage]) -> Bool {
        messages.contains { message in
            guard case let .parts(parts) = message.content else { return false }
            return parts.contains { part in
                if case .image = part { return true }
                return false
            }
        }
    }
    private init() {}

    func complete(
        messages: [OpenAIMessage],
        tools: [OpenAITool] = []
    ) async throws -> OpenAICompletion {
        try Self.validateImagePayloads(in: messages)
        let configuration = await MainActor.run { LLMSettingsStore.shared.configuration }
        guard let configuration,
              !configuration.model.isEmpty,
              let key = await MainActor.run(body: { LLMSettingsStore.shared.readAPIKey() }),
              !key.isEmpty,
              let origin = LLMOrigin(configuration.baseURL) else {
            throw OpenAITransportError(code: .configurationRequired)
        }
        guard origin.scheme == "https" else {
            throw OpenAITransportError(code: .invalidEndpoint)
        }

        let body = OpenAIRequest(
            model: configuration.model,
            messages: messages,
            tools: tools.isEmpty ? nil : tools,
            temperature: 0.2
        )
        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(body)
        } catch {
            throw OpenAITransportError(code: .decodingFailed)
        }

        var request = URLRequest(url: configuration.baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let delegate = OpenAIOriginPinningDelegate(origin: origin)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
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
            containsImage: Self.containsImage(in: messages)
        ):
            throw OpenAITransportError(code: .visionUnsupported)
        default:
            throw OpenAITransportError(code: .serverError)
        }

        do {
            return try JSONDecoder().decode(OpenAICompletion.self, from: data)
        } catch {
            throw OpenAITransportError(code: .decodingFailed)
        }
    }
}
