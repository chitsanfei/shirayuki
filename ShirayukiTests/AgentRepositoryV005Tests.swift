import Foundation
import XCTest
@testable import Shirayuki

final class AgentRepositoryV005Tests: XCTestCase {
    @MainActor
    func testBlockedRepositoryMutationAndPersistence() async throws {
        let suite = "BlockedWordsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsBlockedWordRepository(defaults: defaults)

        let added = try await repository.add(display: " Café ")
        XCTAssertEqual(added.snapshot.revision, 1)
        XCTAssertEqual(added.snapshot.rules.first?.displayValue, "Café")
        let duplicate = try await repository.add(display: "ＣＡＦＥ")
        XCTAssertEqual(duplicate, .unchanged(reason: .duplicate, snapshot: added.snapshot))

        let updated = try await repository.update(
            normalizedOld: try XCTUnwrap(added.snapshot.rules.first?.normalizedKey),
            newDisplay: "CAFE"
        )
        XCTAssertEqual(updated.snapshot.revision, 2)
        XCTAssertEqual(updated.snapshot.rules.first?.displayValue, "CAFE")

        let restored = UserDefaultsBlockedWordRepository(defaults: defaults)
        let restoredSnapshot = await restored.snapshot()
        XCTAssertEqual(restoredSnapshot, updated.snapshot)
        XCTAssertTrue(restored.confirmationRequired)
        restored.setConfirmationRequired(false)
        XCTAssertFalse(UserDefaultsBlockedWordRepository(defaults: defaults).confirmationRequired)
    }

    @MainActor
    func testBlockedRepositoryLimit() async throws {
        let suite = "BlockedWordsLimitTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsBlockedWordRepository(defaults: defaults)
        for index in 0..<100 { _ = try await repository.add(display: "word-\(index)") }
        await XCTAssertThrowsErrorAsync(try await repository.add(display: "word-100")) {
            XCTAssertEqual($0 as? BlockedWordValidationError, .limitReached)
        }
    }


    func testLegacySessionWithoutCompactionDecodes() throws {
        let session = AgentSession(
            id: UUID(),
            ownerKey: AgentSessionOwner.anonymous,
            title: "Legacy",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2),
            messages: []
        )
        let encoded = try JSONEncoder().encode(session)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "compaction")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(AgentSession.self, from: legacyData)
        XCTAssertNil(decoded.compaction)
        XCTAssertEqual(decoded.id, session.id)
    }
    func testFileRepositoryRoundTripIsolationRepairAndDeleteAll() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileAgentSessionRepository(baseDirectory: directory)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let call = AgentLLMToolCall(id: "call-1", name: "currentContext", arguments: "{}")
        let session = AgentSession(
            id: UUID(),
            ownerKey: "anonymous",
            title: "hello",
            createdAt: now,
            updatedAt: now,
            messages: [
                .user(turnID: "turn-1", text: "hello", closesTurn: false),
                .assistant(
                    turnID: "turn-1",
                    envelope: AgentAssistantEnvelope(text: nil, toolCalls: [call]),
                    closesTurn: false
                )
            ]
        )

        try await repository.upsert(session)
        let loaded = try await repository.load(id: session.id, ownerKey: "anonymous")
        let repaired = try XCTUnwrap(loaded)
        XCTAssertEqual(repaired.messages.count, 3)
        XCTAssertEqual(repaired.messages.last, .tool(turnID: "turn-1", callID: "call-1", content: "interrupted", closesTurn: true))
        let otherSessions = try await repository.list(ownerKey: "other")
        let storedBytes = try await repository.totalByteCount()
        XCTAssertEqual(otherSessions, [])
        XCTAssertGreaterThan(storedBytes, 0)
        try await repository.deleteAll()
        let deletedBytes = try await repository.totalByteCount()
        XCTAssertEqual(deletedBytes, 0)
    }


    func testFileRepositoryIsolatesTwoOwners() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileAgentSessionRepository(baseDirectory: directory)
        let now = Date()
        let ownerA = AgentSessionOwner.pica(userID: "account-a")
        let ownerB = AgentSessionOwner.pica(userID: "account-b")
        for owner in [ownerA, ownerB] {
            try await repository.upsert(.init(
                id: UUID(),
                ownerKey: owner,
                title: owner,
                createdAt: now,
                updatedAt: now,
                messages: [.user(turnID: UUID().uuidString, text: owner, closesTurn: true)]
            ))
        }

        let ownerASessions = try await repository.list(ownerKey: ownerA)
        let ownerBSessions = try await repository.list(ownerKey: ownerB)
        let anonymousSessions = try await repository.list(ownerKey: AgentSessionOwner.anonymous)
        XCTAssertEqual(ownerASessions.map(\.ownerKey), [ownerA])
        XCTAssertEqual(ownerBSessions.map(\.ownerKey), [ownerB])
        XCTAssertEqual(anonymousSessions, [])
    }
    @MainActor
    func testBlockedToolConfirmationAndSessionScopedSuccessReceipt() async throws {
        let suite = "BlockedToolTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsBlockedWordRepository(defaults: defaults)
        let service = AgentCommandService(
            blockedWords: repository,
            sessionIsLoggedIn: { true }
        )
        let sessionID = UUID()
        let command = AgentCommand.addBlockedWord(word: "Café", commandID: "call-1")

        guard case .requiresConfirmation(.blockedWordAdd) = await service.execute(
            command,
            sessionID: sessionID
        ) else {
            return XCTFail("Expected blocked-word confirmation")
        }
        let applied = await service.execute(command, sessionID: sessionID, confirmed: true)
        guard case let .blockedWords(snapshot, _) = applied else {
            return XCTFail("Expected blocked-word result")
        }
        XCTAssertEqual(snapshot.revision, 1)

        let replay = await service.execute(command, sessionID: sessionID, confirmed: true)
        XCTAssertEqual(replay, applied)
        let replaySnapshot = await repository.snapshot()
        XCTAssertEqual(replaySnapshot.revision, 1)

        repository.setConfirmationRequired(false)
        let immediate = await service.execute(
            .addBlockedWord(word: "second", commandID: "call-2"),
            sessionID: sessionID
        )
        guard case let .blockedWords(immediateSnapshot, _) = immediate else {
            return XCTFail("Expected immediate mutation")
        }
        XCTAssertEqual(immediateSnapshot.revision, 2)
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
