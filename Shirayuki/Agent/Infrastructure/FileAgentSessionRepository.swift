import Foundation

nonisolated enum AgentSessionRepositoryError: Error, Equatable, Sendable {
    case sessionLimitReached
    case invalidStore
}

actor FileAgentSessionRepository: AgentSessionRepository {
    private struct Envelope: Codable {
        let version: Int
        var sessions: [AgentSession]
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var didRepairOnLoad = false

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        let root = baseDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = root
            .appendingPathComponent("Shirayuki", isDirectory: true)
            .appendingPathComponent("AgentSessions", isDirectory: true)
            .appendingPathComponent("sessions.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func list(ownerKey: String) async throws -> [AgentSessionMetadata] {
        let envelope = try repairedEnvelope()
        return try envelope.sessions
            .filter { $0.ownerKey == ownerKey }
            .map(metadata)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func load(id: UUID, ownerKey: String) async throws -> AgentSession? {
        try repairedEnvelope().sessions.first { $0.id == id && $0.ownerKey == ownerKey }
    }

    func upsert(_ session: AgentSession) async throws {
        var envelope = try loadEnvelope()
        let fitted = try fit(session)
        if let index = envelope.sessions.firstIndex(where: { $0.id == fitted.id && $0.ownerKey == fitted.ownerKey }) {
            envelope.sessions[index] = fitted
        } else {
            envelope.sessions.append(fitted)
        }
        try persist(envelope)
    }

    func delete(id: UUID, ownerKey: String) async throws {
        var envelope = try loadEnvelope()
        envelope.sessions.removeAll { $0.id == id && $0.ownerKey == ownerKey }
        try persist(envelope)
    }

    func totalByteCount() async throws -> Int {
        guard fileManager.fileExists(atPath: fileURL.path) else { return 0 }
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        return (attributes[.size] as? NSNumber)?.intValue ?? 0
    }

    func deleteAll() async throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private func loadEnvelope() throws -> Envelope {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return Envelope(version: 1, sessions: [])
        }
        do {
            let envelope = try decoder.decode(Envelope.self, from: Data(contentsOf: fileURL))
            guard envelope.version == 1 else { throw AgentSessionRepositoryError.invalidStore }
            return envelope
        } catch let error as AgentSessionRepositoryError {
            throw error
        } catch {
            throw AgentSessionRepositoryError.invalidStore
        }
    }

    private func repairedEnvelope() throws -> Envelope {
        if didRepairOnLoad { return try loadEnvelope() }
        var envelope = try loadEnvelope()
        var changed = false
        for index in envelope.sessions.indices {
            let repaired = repairInterruptedTurns(in: envelope.sessions[index])
            if repaired != envelope.sessions[index] {
                envelope.sessions[index] = repaired
                changed = true
            }
        }
        if changed { try persist(envelope) }
        didRepairOnLoad = true
        return envelope
    }

    private func repairInterruptedTurns(in session: AgentSession) -> AgentSession {
        var session = session
        let orderedTurnIDs = session.messages.reduce(into: [String]()) { result, message in
            if !result.contains(message.turnID) { result.append(message.turnID) }
        }
        for turnID in orderedTurnIDs {
            let indices = session.messages.indices.filter { session.messages[$0].turnID == turnID }
            guard let lastIndex = indices.last,
                  !indices.contains(where: { session.messages[$0].closesTurn }) else { continue }

            let calls = indices.flatMap { index -> [AgentLLMToolCall] in
                guard case let .assistant(_, envelope, _) = session.messages[index] else { return [] }
                return envelope.toolCalls
            }
            let observed = Set(indices.compactMap { index -> String? in
                guard case let .tool(_, callID, _, _) = session.messages[index] else { return nil }
                return callID
            })
            let missing = calls.filter { !observed.contains($0.id) }
            if missing.isEmpty {
                session.messages[lastIndex] = closing(session.messages[lastIndex])
            } else {
                for (offset, call) in missing.enumerated() {
                    session.messages.append(.tool(
                        turnID: turnID,
                        callID: call.id,
                        content: "interrupted",
                        closesTurn: offset == missing.count - 1
                    ))
                }
            }
        }
        return session
    }

    private func closing(_ message: AgentProtocolMessageRecord) -> AgentProtocolMessageRecord {
        switch message {
        case let .user(turnID, text, _): .user(turnID: turnID, text: text, closesTurn: true)
        case let .assistant(turnID, envelope, _): .assistant(turnID: turnID, envelope: envelope, closesTurn: true)
        case let .tool(turnID, callID, content, _):
            .tool(turnID: turnID, callID: callID, content: content, closesTurn: true)
        }
    }

    private func fit(_ original: AgentSession) throws -> AgentSession {
        var session = original
        while try exceedsLimits(session) {
            let currentTurnID = session.messages.last?.turnID
            let candidate = session.messages.first { message in
                message.turnID != currentTurnID
                    && session.messages.contains(where: { $0.turnID == message.turnID && $0.closesTurn })
            }?.turnID
            guard let candidate else { throw AgentSessionRepositoryError.sessionLimitReached }
            session.messages.removeAll { $0.turnID == candidate }
        }
        return session
    }

    private func exceedsLimits(_ session: AgentSession) throws -> Bool {
        if session.messages.count > AgentSessionLimits.maximumMessages { return true }
        return try encoder.encode(session).count > AgentSessionLimits.maximumEncodedBytes
    }

    private func metadata(for session: AgentSession) throws -> AgentSessionMetadata {
        AgentSessionMetadata(
            id: session.id,
            ownerKey: session.ownerKey,
            title: session.title,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
            byteCount: try encoder.encode(session).count
        )
    }

    private func persist(_ envelope: Envelope) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporaryURL = directory.appendingPathComponent(".sessions-\(UUID().uuidString).tmp")
        do {
            try encoder.encode(envelope).write(to: temporaryURL)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(fileURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }
}
