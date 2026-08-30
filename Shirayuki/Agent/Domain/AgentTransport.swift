import Foundation

nonisolated struct AgentLLMToolCall: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let arguments: String
}

nonisolated struct AgentAssistantEnvelope: Codable, Equatable, Sendable {
    let text: String?
    let toolCalls: [AgentLLMToolCall]
}

nonisolated enum AgentTransportMessage: Equatable, Sendable {
    case system(String)
    case user(String)
    case assistant(AgentAssistantEnvelope)
    case tool(callID: String, content: String)
    case transientImage(callID: String, prompt: String, jpegData: Data)
}

nonisolated struct AgentToolDefinition: Equatable, Sendable {
    let name: String
    let description: String
    let parametersJSON: String
}

nonisolated struct AgentTransportRequest: Equatable, Sendable {
    let messages: [AgentTransportMessage]
    let tools: [AgentToolDefinition]
}

nonisolated protocol AgentLLMTransport: Sendable {
    func complete(_ request: AgentTransportRequest) async throws -> AgentAssistantEnvelope
}

nonisolated struct AgentParsedToolCall: Equatable, Sendable {
    let callID: String
    let command: AgentCommand
}

nonisolated enum AgentToolParseError: String, Error, Codable, Equatable, Sendable {
    case invalidJSON = "invalid_json"
    case unknownTool = "unknown_tool"
    case unknownArgument = "unknown_argument"
    case missingArgument = "missing_argument"
    case invalidType = "invalid_type"
    case invalidValue = "invalid_value"
    case valueOutOfRange = "value_out_of_range"
}

nonisolated protocol AgentToolCallParsing: Sendable {
    func parse(_ call: AgentLLMToolCall) -> Result<AgentParsedToolCall, AgentToolParseError>
    var definitions: [AgentToolDefinition] { get }
}
