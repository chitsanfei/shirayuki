import Foundation
import XCTest
@testable import Shirayuki

final class AgentLoopV005Tests: XCTestCase {
    func testLoopDrainsAllCallsBeforeNextRequest() async throws {
        let first = AgentAssistantEnvelope(text: nil, toolCalls: [
            .init(id: "a", name: "currentContext", arguments: "{}"),
            .init(id: "b", name: "currentContext", arguments: "{}")
        ])
        let transport = ScriptedTransport([first, .init(text: "done", toolCalls: [])])
        let repository = MemorySessionRepository()
        let loop = AgentLoop(
            transport: transport,
            parser: ContextParser(),
            executor: RecordingExecutor(),
            sessions: repository
        )
        let session = makeSession()

        let outcome = try await loop.send("hello", in: session, systemPrompt: "system")
        guard case let .completed(completed) = outcome else { return XCTFail("Expected completion") }
        XCTAssertEqual(completed.messages.count, 5)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[1].messages.compactMap(\.toolCallID), ["a", "b"])
    }

    func testToolCallLimitDoesNotExecuteExcessCalls() async throws {
        let transport = ScriptedTransport((1...4).map { index in
            .init(
                text: nil,
                toolCalls: [.init(id: "call-\(index)", name: "currentContext", arguments: "{}")]
            )
        })
        let executor = RecordingExecutor()
        let loop = AgentLoop(
            transport: transport,
            parser: ContextParser(),
            executor: executor,
            sessions: MemorySessionRepository(),
            maximumToolCalls: 3
        )

        let outcome = try await loop.send("loop", in: makeSession(), systemPrompt: "system")
        guard case let .failed(session, code) = outcome else {
            return XCTFail("Expected tool-call limit")
        }
        XCTAssertEqual(code, "tool_call_limit_reached")
        let executionCount = await executor.executionCount
        XCTAssertEqual(executionCount, 3)
        XCTAssertTrue(session.messages.contains {
            if case let .tool(_, _, content, _) = $0 {
                return content == "tool_call_limit_reached"
            }
            return false
        })
        let requests = await transport.requests
        XCTAssertTrue(requests[3].tools.isEmpty)
    }

    func testNearToolCallLimitInjectsDirectAnswerPromptAtNMinusTwo() async throws {
        let responses = (1...3).map { index in
            AgentAssistantEnvelope(
                text: nil,
                toolCalls: [.init(id: "call-\(index)", name: "currentContext", arguments: "{}")]
            )
        } + [.init(text: "direct answer", toolCalls: [])]
        let transport = ScriptedTransport(responses)
        let loop = AgentLoop(
            transport: transport,
            parser: ContextParser(),
            executor: RecordingExecutor(),
            sessions: MemorySessionRepository(),
            maximumToolCalls: 5
        )

        let outcome = try await loop.send("loop", in: makeSession(), systemPrompt: "system")
        guard case .completed = outcome else { return XCTFail("Expected direct final answer") }
        let requests = await transport.requests
        let promptText = requests[3].messages.map(\.debugText).joined(separator: "\n")
        XCTAssertTrue(promptText.contains("TOOL_CALL_BUDGET_NEAR_LIMIT"))
        XCTAssertTrue(promptText.contains("Respond directly now"))
        XCTAssertFalse(requests[3].tools.isEmpty)
    }

    func testConfirmationRejectResumesEnvelope() async throws {
        let first = AgentAssistantEnvelope(text: nil, toolCalls: [
            .init(id: "confirm", name: "currentContext", arguments: "{}"),
            .init(id: "next", name: "currentContext", arguments: "{}")
        ])
        let transport = ScriptedTransport([first, .init(text: "done", toolCalls: [])])
        let repository = MemorySessionRepository()
        let loop = AgentLoop(
            transport: transport,
            parser: ContextParser(),
            executor: ConfirmationExecutor(),
            sessions: repository
        )

        let initial = try await loop.send("hello", in: makeSession(), systemPrompt: "system")
        guard case let .suspended(session, suspension) = initial else { return XCTFail("Expected suspension") }
        XCTAssertEqual(suspension.toolCallCount, 1)
        let resumed = try await loop.resume(suspension, session: session, confirmed: false)
        guard case let .completed(completed) = resumed else { return XCTFail("Expected completion") }
        XCTAssertTrue(completed.messages.contains {
            if case let .tool(_, callID, content, _) = $0 { return callID == "confirm" && content == "user_rejected" }
            return false
        })
    }

    func testUserMessagePublishesBeforeTransportFailure() async throws {
        let repository = MemorySessionRepository()
        let updates = SessionUpdateRecorder()
        let loop = AgentLoop(
            transport: ThrowingTransport(),
            parser: ContextParser(),
            executor: RecordingExecutor(),
            sessions: repository,
            onSessionUpdate: { session in await updates.append(session) }
        )

        do {
            _ = try await loop.send("visible immediately", in: makeSession(), systemPrompt: "system")
            XCTFail("Expected transport failure")
        } catch {
            let sessions = await updates.sessions
            XCTAssertFalse(sessions.isEmpty)
            guard case let .user(_, text, _) = sessions.first?.messages.first else {
                return XCTFail("Expected published user message")
            }
            XCTAssertEqual(text, "visible immediately")
        }
    }

    func testAutoCompactionSummarizesOldTurnsAndPreservesLocalHistory() async throws {
        let transport = ScriptedTransport([
            .init(text: "compacted facts", toolCalls: []),
            .init(text: "final", toolCalls: [])
        ])
        let repository = MemorySessionRepository()
        let updates = SessionUpdateRecorder()
        let loop = AgentLoop(
            transport: transport,
            parser: ContextParser(),
            executor: RecordingExecutor(),
            sessions: repository,
            onSessionUpdate: { session in await updates.append(session) }
        )
        var session = makeSession()
        for index in 0..<6 {
            session.messages.append(.user(
                turnID: "turn-\(index)",
                text: "old-context-\(index)-\(String(repeating: "x", count: 32))",
                closesTurn: true
            ))
        }

        let compacted = await loop.compactIfNeeded(
            session,
            policy: .init(enabled: true, thresholdBytes: 1, preservedRecentTurns: 2)
        )
        XCTAssertEqual(compacted.messages.count, 6)
        XCTAssertEqual(compacted.compaction?.summary, "compacted facts")
        XCTAssertEqual(compacted.compaction?.coveredTurnIDs.count, 4)

        _ = try await loop.send("new turn", in: compacted, systemPrompt: "system")
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2)
        let replay = requests[1].messages.map(\.debugText).joined(separator: "\n")
        XCTAssertTrue(replay.contains("compacted facts"))
        XCTAssertFalse(replay.contains("old-context-0"))
        XCTAssertTrue(replay.contains("old-context-4"))
        XCTAssertTrue(replay.contains("new turn"))
    }

    func testAutoCompactionFailureKeepsOriginalHistory() async {
        let loop = AgentLoop(
            transport: ThrowingTransport(),
            parser: ContextParser(),
            executor: RecordingExecutor(),
            sessions: MemorySessionRepository()
        )
        var session = makeSession()
        for index in 0..<6 {
            session.messages.append(.user(
                turnID: "turn-\(index)",
                text: String(repeating: "x", count: 64),
                closesTurn: true
            ))
        }
        let result = await loop.compactIfNeeded(
            session,
            policy: .init(enabled: true, thresholdBytes: 1, preservedRecentTurns: 2)
        )
        XCTAssertEqual(result, session)
    }

    func testReaderImageFlowsToVisionModelAndReturnsDescription() async throws {
        let transport = ScriptedTransport([
            .init(
                text: nil,
                toolCalls: [.init(id: "image-call", name: "currentPageContent", arguments: "{}")]
            ),
            .init(text: "The page shows two characters talking.", toolCalls: [])
        ])
        let loop = AgentLoop(
            transport: transport,
            parser: CurrentPageParser(),
            executor: VisionExecutor(),
            sessions: MemorySessionRepository()
        )

        let initial = try await loop.send(
            "What am I reading?",
            in: makeSession(),
            systemPrompt: "system"
        )
        guard case let .suspended(session, suspension) = initial else {
            return XCTFail("Expected image confirmation")
        }
        let result = try await loop.resume(suspension, session: session, confirmed: true)
        guard case let .completed(completed) = result else {
            return XCTFail("Expected vision description")
        }
        XCTAssertTrue(completed.messages.contains { message in
            guard case let .assistant(_, envelope, _) = message else { return false }
            return envelope.text == "The page shows two characters talking."
        })
        let requests = await transport.requests
        XCTAssertTrue(requests[1].messages.contains { message in
            if case .transientImage = message { return true }
            return false
        })
    }

    func testVisionRejectionReplacesReadyObservationAndClosesTurn() async throws {
        let transport = VisionRejectingTransport()
        let loop = AgentLoop(
            transport: transport,
            parser: CurrentPageParser(),
            executor: VisionExecutor(),
            sessions: MemorySessionRepository()
        )
        let initial = try await loop.send(
            "What am I reading?",
            in: makeSession(),
            systemPrompt: "system"
        )
        guard case let .suspended(session, suspension) = initial else {
            return XCTFail("Expected image confirmation")
        }
        let result = try await loop.resume(suspension, session: session, confirmed: true)
        guard case let .failed(failed, code) = result else {
            return XCTFail("Expected vision unsupported result")
        }
        XCTAssertEqual(code, "visionUnsupported")
        XCTAssertTrue(failed.messages.contains { message in
            guard case let .tool(_, callID, content, closesTurn) = message else { return false }
            return callID == "image-call"
                && content == "vision_unsupported"
                && closesTurn
        })
        XCTAssertFalse(failed.messages.contains { message in
            guard case let .tool(_, _, content, _) = message else { return false }
            return content == "current_page_image_ready"
        })
    }

    private func makeSession() -> AgentSession {
        AgentSession(
            id: UUID(),
            ownerKey: "anonymous",
            title: "hello",
            createdAt: Date(),
            updatedAt: Date(),
            messages: []
        )
    }
}

private extension AgentTransportMessage {
    var toolCallID: String? {
        guard case let .tool(callID, _) = self else { return nil }
        return callID
    }

    var debugText: String {
        switch self {
        case let .system(text), let .user(text): text
        case let .assistant(envelope):
            (envelope.text ?? "") + envelope.toolCalls.map(\.arguments).joined()
        case let .tool(callID, content): "\(callID) \(content)"
        case let .transientImage(callID, prompt, _): "\(callID) \(prompt)"
        }
    }
}

private actor ScriptedTransport: AgentLLMTransport {
    private var responses: [AgentAssistantEnvelope]
    private(set) var requests: [AgentTransportRequest] = []

    init(_ responses: [AgentAssistantEnvelope]) { self.responses = responses }

    func complete(_ request: AgentTransportRequest) async throws -> AgentAssistantEnvelope {
        requests.append(request)
        return responses.removeFirst()
    }
}

private actor RepeatingToolTransport: AgentLLMTransport {
    private var index = 0

    func complete(_ request: AgentTransportRequest) async throws -> AgentAssistantEnvelope {
        index += 1
        return .init(text: nil, toolCalls: [.init(id: "call-\(index)", name: "currentContext", arguments: "{}")])
    }
}

private struct ThrowingTransport: AgentLLMTransport {
    func complete(_ request: AgentTransportRequest) async throws -> AgentAssistantEnvelope {
        throw OpenAITransportError(code: .networkFailed)
    }
}

private actor VisionRejectingTransport: AgentLLMTransport {
    private var requestCount = 0

    func complete(_ request: AgentTransportRequest) async throws -> AgentAssistantEnvelope {
        requestCount += 1
        if requestCount == 1 {
            return .init(
                text: nil,
                toolCalls: [.init(id: "image-call", name: "currentPageContent", arguments: "{}")]
            )
        }
        throw OpenAITransportError(code: .visionUnsupported)
    }
}

private actor SessionUpdateRecorder {
    private(set) var sessions: [AgentSession] = []

    func append(_ session: AgentSession) {
        sessions.append(session)
    }
}

private struct ContextParser: AgentToolCallParsing {
    let definitions = [AgentToolDefinition(name: "currentContext", description: "", parametersJSON: #"{"type":"object","properties":{},"additionalProperties":false}"#)]

    func parse(_ call: AgentLLMToolCall) -> Result<AgentParsedToolCall, AgentToolParseError> {
        .success(.init(callID: call.id, command: .currentContext))
    }
}

private struct CurrentPageParser: AgentToolCallParsing {
    let definitions = [
        AgentToolDefinition(
            name: "currentPageContent",
            description: "",
            parametersJSON: #"{"type":"object","properties":{},"additionalProperties":false}"#
        )
    ]

    func parse(_ call: AgentLLMToolCall) -> Result<AgentParsedToolCall, AgentToolParseError> {
        .success(.init(callID: call.id, command: .currentPageContent))
    }
}

private actor RecordingExecutor: AgentLoopCommandExecutor {
    private(set) var executionCount = 0

    func execute(_ command: AgentCommand, sessionID: UUID, turnID: String, confirmed: Bool) async -> AgentCommandExecution {
        executionCount += 1
        return .observation("ok")
    }
}

private actor ConfirmationExecutor: AgentLoopCommandExecutor {
    private var first = true

    func execute(_ command: AgentCommand, sessionID: UUID, turnID: String, confirmed: Bool) async -> AgentCommandExecution {
        if first {
            first = false
            return .confirmation(.currentPage(providerHost: "example.com"))
        }
        return .observation("ok")
    }
}

private actor VisionExecutor: AgentLoopCommandExecutor {
    func execute(
        _ command: AgentCommand,
        sessionID: UUID,
        turnID: String,
        confirmed: Bool
    ) async -> AgentCommandExecution {
        if confirmed {
            return .observation(
                "current_page_image_ready",
                transientImage: Data([0xFF, 0xD8, 0xFF, 0xD9])
            )
        }
        return .confirmation(.currentPage(providerHost: "example.com"))
    }
}

private actor MemorySessionRepository: AgentSessionRepository {
    private var sessions: [UUID: AgentSession] = [:]

    func list(ownerKey: String) async throws -> [AgentSessionMetadata] { [] }
    func load(id: UUID, ownerKey: String) async throws -> AgentSession? { sessions[id] }
    func upsert(_ session: AgentSession) async throws { sessions[session.id] = session }
    func delete(id: UUID, ownerKey: String) async throws { sessions[id] = nil }
    func totalByteCount() async throws -> Int { 0 }
    func deleteAll() async throws { sessions.removeAll() }
}
