import Foundation
import CryptoKit

nonisolated enum AgentProtocolMessageRecord: Codable, Equatable, Sendable {
    case user(turnID: String, text: String, closesTurn: Bool)
    case assistant(turnID: String, envelope: AgentAssistantEnvelope, closesTurn: Bool)
    case tool(turnID: String, callID: String, content: String, closesTurn: Bool)

    var turnID: String {
        switch self {
        case let .user(turnID, _, _), let .assistant(turnID, _, _), let .tool(turnID, _, _, _): turnID
        }
    }

    var closesTurn: Bool {
        switch self {
        case let .user(_, _, closesTurn),
             let .assistant(_, _, closesTurn),
             let .tool(_, _, _, closesTurn):
            closesTurn
        }
    }
}

nonisolated struct AgentContextCompaction: Codable, Equatable, Sendable {
    var summary: String
    var coveredTurnIDs: Set<String>
    var updatedAt: Date
}

nonisolated struct AgentContextCompactionPolicy: Equatable, Sendable {
    let enabled: Bool
    let thresholdBytes: Int
    let preservedRecentTurns: Int
}

nonisolated struct AgentSession: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let ownerKey: String
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [AgentProtocolMessageRecord]
    var compaction: AgentContextCompaction? = nil
}

nonisolated struct AgentSessionMetadata: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let ownerKey: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let byteCount: Int
}

nonisolated protocol AgentSessionRepository: Sendable {
    func list(ownerKey: String) async throws -> [AgentSessionMetadata]
    func load(id: UUID, ownerKey: String) async throws -> AgentSession?
    func upsert(_ session: AgentSession) async throws
    func delete(id: UUID, ownerKey: String) async throws
    func totalByteCount() async throws -> Int
    func deleteAll() async throws
}

nonisolated enum AgentSessionOwner {
    static let anonymous = "anonymous"

    static func pica(userID: String) -> String {
        let digest = SHA256.hash(data: Data(userID.utf8))
        return "pica:" + digest.map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated enum AgentSessionLimits {
    static let maximumUserBytes = 16 * 1024
    static let maximumAssistantBytes = 64 * 1024
    static let maximumObservationBytes = 64 * 1024
    static let maximumMessages = 100
    static let maximumEncodedBytes = 512 * 1024
    static let maximumTitleCharacters = 40

    static func validateUserText(_ text: String) -> Bool {
        text.lengthOfBytes(using: .utf8) <= maximumUserBytes
    }

    static func title(from text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumTitleCharacters))
    }

    static func boundedAssistantText(_ text: String, truncatedSuffix: String) -> String {
        guard text.lengthOfBytes(using: .utf8) > maximumAssistantBytes else { return text }
        let suffixBytes = truncatedSuffix.lengthOfBytes(using: .utf8)
        let limit = max(0, maximumAssistantBytes - suffixBytes)
        var result = ""
        result.reserveCapacity(limit)
        for character in text {
            let candidate = result + String(character)
            guard candidate.lengthOfBytes(using: .utf8) <= limit else { break }
            result = candidate
        }
        return result + truncatedSuffix
    }

    static func boundedObservation(_ text: String) -> String {
        text.lengthOfBytes(using: .utf8) <= maximumObservationBytes
            ? text
            : "observation_too_large"
    }
}
