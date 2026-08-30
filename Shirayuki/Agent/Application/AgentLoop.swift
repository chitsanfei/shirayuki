import Foundation

nonisolated enum AgentCommandExecution: Sendable {
    case observation(String, transientImage: Data? = nil)
    case confirmation(AgentConfirmationPreview)
}

protocol AgentLoopCommandExecutor: Sendable {
    func execute(
        _ command: AgentCommand,
        sessionID: UUID,
        turnID: String,
        confirmed: Bool
    ) async -> AgentCommandExecution
}

nonisolated struct AgentLoopSuspension: Sendable {
    let sessionID: UUID
    let turnID: String
    let assistantEnvelope: AgentAssistantEnvelope
    let callIndex: Int
    let command: AgentCommand
    let preview: AgentConfirmationPreview
    let modelStep: Int
    let toolCallCount: Int
    let systemPrompt: String
}

nonisolated enum AgentLoopOutcome: Sendable {
    case completed(AgentSession)
    case suspended(AgentSession, AgentLoopSuspension)
    case failed(AgentSession, code: String)
}

actor AgentLoop {
    static let maximumModelSteps = 24

    private let transport: any AgentLLMTransport
    private let parser: any AgentToolCallParsing
    private let executor: any AgentLoopCommandExecutor
    private let sessions: any AgentSessionRepository
    private let onSessionUpdate: @Sendable (AgentSession) async -> Void
    private let maximumToolCalls: Int

    init(
        transport: any AgentLLMTransport,
        parser: any AgentToolCallParsing,
        executor: any AgentLoopCommandExecutor,
        sessions: any AgentSessionRepository,
        maximumToolCalls: Int = 10,
        onSessionUpdate: @escaping @Sendable (AgentSession) async -> Void = { _ in }
    ) {
        self.transport = transport
        self.parser = parser
        self.executor = executor
        self.sessions = sessions
        self.maximumToolCalls = min(max(maximumToolCalls, 1), 20)
        self.onSessionUpdate = onSessionUpdate
    }

    func compactIfNeeded(
        _ original: AgentSession,
        policy: AgentContextCompactionPolicy
    ) async -> AgentSession {
        guard policy.enabled,
              contextByteCount(original) > policy.thresholdBytes else { return original }

        let covered = original.compaction?.coveredTurnIDs ?? []
        let closedTurnIDs = original.messages.reduce(into: [String]()) { result, message in
            guard message.closesTurn,
                  !covered.contains(message.turnID),
                  !result.contains(message.turnID) else { return }
            result.append(message.turnID)
        }
        let compactedTurnIDs = Set(closedTurnIDs.dropLast(policy.preservedRecentTurns))
        guard !compactedTurnIDs.isEmpty else { return original }

        var compactionMessages: [AgentTransportMessage] = [
            .system(
                "Compress prior conversation context. Preserve user goals, identifiers, decisions, confirmed actions, tool facts, unresolved work, and safety constraints. Omit hidden reasoning. Return only a concise factual summary."
            )
        ]
        if let previous = original.compaction?.summary, !previous.isEmpty {
            compactionMessages.append(.user("Previous compacted context:\n\(previous)"))
        }
        compactionMessages += original.messages
            .filter { compactedTurnIDs.contains($0.turnID) }
            .map(transportMessage)

        do {
            let envelope = try await transport.complete(.init(
                messages: compactionMessages,
                tools: []
            ))
            guard envelope.toolCalls.isEmpty,
                  let summary = envelope.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !summary.isEmpty else { return original }

            var session = original
            var coveredTurnIDs = covered
            coveredTurnIDs.formUnion(compactedTurnIDs)
            session.compaction = AgentContextCompaction(
                summary: Self.boundedCompactionSummary(summary),
                coveredTurnIDs: coveredTurnIDs,
                updatedAt: Date()
            )
            session.updatedAt = Date()
            try await persist(session)
            return session
        } catch {
            return original
        }
    }

    func send(
        _ userText: String,
        in original: AgentSession,
        systemPrompt: String,
        truncatedSuffix: String = "[truncated]"
    ) async throws -> AgentLoopOutcome {
        guard AgentSessionLimits.validateUserText(userText) else {
            return .failed(original, code: "input_too_large")
        }
        let turnID = UUID().uuidString
        var session = original
        session.messages.append(.user(turnID: turnID, text: userText, closesTurn: false))
        session.updatedAt = Date()
        try await persist(session)
        return try await requestModel(
            session: session,
            turnID: turnID,
            systemPrompt: systemPrompt,
            startingStep: 1,
            processedToolCallCount: 0,
            transientImage: nil,
            truncatedSuffix: truncatedSuffix
        )
    }

    func resume(
        _ suspension: AgentLoopSuspension,
        session original: AgentSession,
        confirmed: Bool,
        truncatedSuffix: String = "[truncated]"
    ) async throws -> AgentLoopOutcome {
        guard original.id == suspension.sessionID else {
            return .failed(original, code: "stale_session")
        }
        var session = original
        if confirmed {
            let execution = await executor.execute(
                suspension.command,
                sessionID: session.id,
                turnID: suspension.turnID,
                confirmed: true
            )
            switch execution {
            case let .observation(content, transientImage):
                appendObservation(
                    AgentSessionLimits.boundedObservation(content),
                    callID: suspension.assistantEnvelope.toolCalls[suspension.callIndex].id,
                    turnID: suspension.turnID,
                    closesTurn: false,
                    to: &session
                )
                try await persist(session)
                return try await drain(
                    session: session,
                    turnID: suspension.turnID,
                    systemPrompt: suspension.systemPrompt,
                    envelope: suspension.assistantEnvelope,
                    startingCallIndex: suspension.callIndex + 1,
                    modelStep: suspension.modelStep,
                    processedToolCallCount: suspension.toolCallCount,
                    transientImage: transientImage,
                    truncatedSuffix: truncatedSuffix
                )
            case .confirmation:
                appendObservation(
                    "capability_unavailable",
                    callID: suspension.assistantEnvelope.toolCalls[suspension.callIndex].id,
                    turnID: suspension.turnID,
                    closesTurn: false,
                    to: &session
                )
                try await persist(session)
                return try await drain(
                    session: session,
                    turnID: suspension.turnID,
                    systemPrompt: suspension.systemPrompt,
                    envelope: suspension.assistantEnvelope,
                    startingCallIndex: suspension.callIndex + 1,
                    modelStep: suspension.modelStep,
                    processedToolCallCount: suspension.toolCallCount,
                    transientImage: nil,
                    truncatedSuffix: truncatedSuffix
                )
            }
        }

        appendObservation(
            "user_rejected",
            callID: suspension.assistantEnvelope.toolCalls[suspension.callIndex].id,
            turnID: suspension.turnID,
            closesTurn: false,
            to: &session
        )
        try await persist(session)
        return try await drain(
            session: session,
            turnID: suspension.turnID,
            systemPrompt: suspension.systemPrompt,
            envelope: suspension.assistantEnvelope,
            startingCallIndex: suspension.callIndex + 1,
            modelStep: suspension.modelStep,
            processedToolCallCount: suspension.toolCallCount,
            transientImage: nil,
            truncatedSuffix: truncatedSuffix
        )
    }

    func cancel(_ suspension: AgentLoopSuspension, session original: AgentSession) async throws -> AgentSession {
        var session = original
        for index in suspension.callIndex..<suspension.assistantEnvelope.toolCalls.count {
            let call = suspension.assistantEnvelope.toolCalls[index]
            appendObservation(
                "cancelled",
                callID: call.id,
                turnID: suspension.turnID,
                closesTurn: index == suspension.assistantEnvelope.toolCalls.count - 1,
                to: &session
            )
        }
        session.updatedAt = Date()
        try await persist(session)
        return session
    }

    private func requestModel(
        session: AgentSession,
        turnID: String,
        systemPrompt: String,
        startingStep: Int,
        processedToolCallCount: Int,
        transientImage: (callID: String, data: Data)?,
        truncatedSuffix: String
    ) async throws -> AgentLoopOutcome {
        var session = session
        for step in startingStep...Self.maximumModelSteps {
            var messages = replayMessages(session, systemPrompt: systemPrompt)
            let nearLimitThreshold = max(0, maximumToolCalls - 2)
            if processedToolCallCount >= nearLimitThreshold {
                let remaining = max(0, maximumToolCalls - processedToolCallCount)
                messages.append(.system(
                    "TOOL_CALL_BUDGET_NEAR_LIMIT: \(remaining) tool calls remain. Respond directly now using information already gathered. Do not call another tool unless the answer would otherwise be incorrect."
                ))
            }
            if let transientImage {
                messages.append(.transientImage(
                    callID: transientImage.callID,
                    prompt: "Current page image for tool call \(transientImage.callID)",
                    jpegData: transientImage.data
                ))
            }
            let envelope: AgentAssistantEnvelope
            do {
                envelope = try await transport.complete(.init(
                    messages: messages,
                    tools: processedToolCallCount >= maximumToolCalls
                        ? []
                        : parser.definitions
                ))
            } catch let error as OpenAITransportError
                where error.code == .visionUnsupported && transientImage != nil {
                replaceObservation(
                    callID: transientImage!.callID,
                    turnID: turnID,
                    content: "vision_unsupported",
                    closesTurn: true,
                    in: &session
                )
                session.updatedAt = Date()
                try await persist(session)
                return .failed(session, code: "visionUnsupported")
            }
            let boundedEnvelope = AgentAssistantEnvelope(
                text: envelope.text.map {
                    AgentSessionLimits.boundedAssistantText($0, truncatedSuffix: truncatedSuffix)
                },
                toolCalls: envelope.toolCalls
            )
            let isFinal = boundedEnvelope.toolCalls.isEmpty
            session.messages.append(.assistant(
                turnID: turnID,
                envelope: boundedEnvelope,
                closesTurn: isFinal
            ))
            session.updatedAt = Date()
            try await persist(session)
            if isFinal { return .completed(session) }

            if step == Self.maximumModelSteps {
                for (index, call) in boundedEnvelope.toolCalls.enumerated() {
                    appendObservation(
                        "step_limit_reached",
                        callID: call.id,
                        turnID: turnID,
                        closesTurn: index == boundedEnvelope.toolCalls.count - 1,
                        to: &session
                    )
                }
                session.updatedAt = Date()
                try await persist(session)
                return .failed(session, code: "step_limit_reached")
            }

            return try await drain(
                session: session,
                turnID: turnID,
                systemPrompt: systemPrompt,
                envelope: boundedEnvelope,
                startingCallIndex: 0,
                modelStep: step,
                processedToolCallCount: processedToolCallCount,
                transientImage: nil,
                truncatedSuffix: truncatedSuffix
            )
        }
        return .failed(session, code: "step_limit_reached")
    }

    private func drain(
        session original: AgentSession,
        turnID: String,
        systemPrompt: String,
        envelope: AgentAssistantEnvelope,
        startingCallIndex: Int,
        modelStep: Int,
        processedToolCallCount: Int,
        transientImage initialTransientImage: Data?,
        truncatedSuffix: String
    ) async throws -> AgentLoopOutcome {
        var session = original
        var toolCallCount = processedToolCallCount
        var transientImage = initialTransientImage.map {
            (callID: envelope.toolCalls[max(0, startingCallIndex - 1)].id, data: $0)
        }
        for index in startingCallIndex..<envelope.toolCalls.count {
            let call = envelope.toolCalls[index]
            if toolCallCount >= maximumToolCalls {
                for remainingIndex in index..<envelope.toolCalls.count {
                    let remainingCall = envelope.toolCalls[remainingIndex]
                    appendObservation(
                        "tool_call_limit_reached",
                        callID: remainingCall.id,
                        turnID: turnID,
                        closesTurn: remainingIndex == envelope.toolCalls.count - 1,
                        to: &session
                    )
                }
                session.updatedAt = Date()
                try await persist(session)
                return .failed(session, code: "tool_call_limit_reached")
            }
            toolCallCount += 1
            switch parser.parse(call) {
            case let .failure(error):
                appendObservation(
                    error.rawValue,
                    callID: call.id,
                    turnID: turnID,
                    closesTurn: false,
                    to: &session
                )
            case let .success(parsed):
                switch await executor.execute(
                    parsed.command,
                    sessionID: session.id,
                    turnID: turnID,
                    confirmed: false
                ) {
                case let .confirmation(preview):
                    try await persist(session)
                    return .suspended(session, AgentLoopSuspension(
                        sessionID: session.id,
                        turnID: turnID,
                        assistantEnvelope: envelope,
                        callIndex: index,
                        command: parsed.command,
                        preview: preview,
                        modelStep: modelStep,
                        toolCallCount: toolCallCount,
                        systemPrompt: systemPrompt
                    ))
                case let .observation(content, image):
                    appendObservation(
                        AgentSessionLimits.boundedObservation(content),
                        callID: call.id,
                        turnID: turnID,
                        closesTurn: false,
                        to: &session
                    )
                    if let image { transientImage = (call.id, image) }
                }
            }
            session.updatedAt = Date()
            try await persist(session)
        }
        return try await requestModel(
            session: session,
            turnID: turnID,
            systemPrompt: systemPrompt,
            startingStep: modelStep + 1,
            processedToolCallCount: toolCallCount,
            transientImage: transientImage,
            truncatedSuffix: truncatedSuffix
        )
    }

    private func replayMessages(
        _ session: AgentSession,
        systemPrompt: String
    ) -> [AgentTransportMessage] {
        let covered = session.compaction?.coveredTurnIDs ?? []
        var messages: [AgentTransportMessage] = [.system(systemPrompt)]
        if let summary = session.compaction?.summary, !summary.isEmpty {
            messages.append(.system("Compacted previous conversation context:\n\(summary)"))
        }
        messages += session.messages
            .filter { !covered.contains($0.turnID) }
            .map(transportMessage)
        return messages
    }

    private func transportMessage(
        _ record: AgentProtocolMessageRecord
    ) -> AgentTransportMessage {
        switch record {
        case let .user(_, text, _): .user(text)
        case let .assistant(_, envelope, _): .assistant(envelope)
        case let .tool(_, callID, content, _): .tool(callID: callID, content: content)
        }
    }

    private func contextByteCount(_ session: AgentSession) -> Int {
        let covered = session.compaction?.coveredTurnIDs ?? []
        let summaryBytes = session.compaction?.summary.lengthOfBytes(using: .utf8) ?? 0
        return summaryBytes + session.messages.reduce(into: 0) { total, record in
            guard !covered.contains(record.turnID) else { return }
            switch record {
            case let .user(_, text, _):
                total += text.lengthOfBytes(using: .utf8)
            case let .assistant(_, envelope, _):
                total += envelope.text?.lengthOfBytes(using: .utf8) ?? 0
                total += envelope.toolCalls.reduce(into: 0) { callBytes, call in
                    callBytes += call.id.utf8.count + call.name.utf8.count + call.arguments.utf8.count
                }
            case let .tool(_, callID, content, _):
                total += callID.utf8.count + content.lengthOfBytes(using: .utf8)
            }
        }
    }

    private static func boundedCompactionSummary(_ summary: String) -> String {
        let maximumBytes = 16 * 1024
        guard summary.lengthOfBytes(using: .utf8) > maximumBytes else { return summary }
        var result = ""
        var byteCount = 0
        for character in summary {
            let value = String(character)
            let bytes = value.lengthOfBytes(using: .utf8)
            guard byteCount + bytes <= maximumBytes else { break }
            result.append(character)
            byteCount += bytes
        }
        return result
    }

    private func persist(_ session: AgentSession) async throws {
        try await sessions.upsert(session)
        await onSessionUpdate(session)
    }

    private func replaceObservation(
        callID: String,
        turnID: String,
        content: String,
        closesTurn: Bool,
        in session: inout AgentSession
    ) {
        guard let index = session.messages.indices.last(where: { index in
            guard case let .tool(messageTurnID, messageCallID, _, _) = session.messages[index] else {
                return false
            }
            return messageTurnID == turnID && messageCallID == callID
        }) else { return }
        session.messages[index] = .tool(
            turnID: turnID,
            callID: callID,
            content: content,
            closesTurn: closesTurn
        )
    }

    private func appendObservation(
        _ content: String,
        callID: String,
        turnID: String,
        closesTurn: Bool,
        to session: inout AgentSession
    ) {
        session.messages.append(.tool(
            turnID: turnID,
            callID: callID,
            content: content,
            closesTurn: closesTurn
        ))
    }
}
