import Combine
import Foundation

@MainActor
final class UserDefaultsBlockedWordRepository: ObservableObject, BlockedWordRepository {
    static let wordsKey = "blocked_words"

    @Published private(set) var currentSnapshot: BlockedWordSnapshot

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private struct Envelope: Codable {
        let version: Int
        let revision: UInt64
        let rules: [BlockedWordRule]
        let includeRules: [BlockedWordRule]

        init(version: Int, revision: UInt64, rules: [BlockedWordRule], includeRules: [BlockedWordRule] = []) {
            self.version = version
            self.revision = revision
            self.rules = rules
            self.includeRules = includeRules
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decode(Int.self, forKey: .version)
            revision = try container.decode(UInt64.self, forKey: .revision)
            rules = try container.decode([BlockedWordRule].self, forKey: .rules)
            includeRules = try container.decodeIfPresent([BlockedWordRule].self, forKey: .includeRules) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case version, revision, rules, includeRules
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.wordsKey),
           let envelope = try? decoder.decode(Envelope.self, from: data),
           envelope.version == 1 {
            currentSnapshot = BlockedWordSnapshot(
                revision: envelope.revision,
                rules: envelope.rules,
                includeRules: envelope.includeRules
            )
        } else {
            currentSnapshot = .empty
        }
    }

    func snapshot() async -> BlockedWordSnapshot { currentSnapshot }

    func add(display: String) async throws -> BlockedWordWriteResult {
        let rule = try BlockedWordCanonicalizer.rule(from: display)
        if currentSnapshot.rules.contains(where: { $0.normalizedKey == rule.normalizedKey }) {
            return .unchanged(reason: .duplicate, snapshot: currentSnapshot)
        }
        guard currentSnapshot.rules.count < BlockedWordCanonicalizer.maximumRuleCount else {
            throw BlockedWordValidationError.limitReached
        }
        return try commit(
            rules: currentSnapshot.rules + [rule],
            includeRules: currentSnapshot.includeRules
        )
    }

    func update(normalizedOld: String, newDisplay: String) async throws -> BlockedWordWriteResult {
        guard let index = currentSnapshot.rules.firstIndex(where: { $0.normalizedKey == normalizedOld }) else {
            throw BlockedWordValidationError.notFound
        }
        let replacement = try BlockedWordCanonicalizer.rule(from: newDisplay)
        if currentSnapshot.rules.enumerated().contains(where: {
            $0.offset != index && $0.element.normalizedKey == replacement.normalizedKey
        }) {
            throw BlockedWordValidationError.duplicateTarget
        }
        guard currentSnapshot.rules[index] != replacement else {
            return .unchanged(reason: .duplicate, snapshot: currentSnapshot)
        }
        var rules = currentSnapshot.rules
        rules[index] = replacement
        return try commit(
            rules: rules,
            includeRules: currentSnapshot.includeRules
        )
    }

    func remove(normalizedKey: String) async throws -> BlockedWordWriteResult {
        guard let index = currentSnapshot.rules.firstIndex(where: { $0.normalizedKey == normalizedKey }) else {
            throw BlockedWordValidationError.notFound
        }
        var rules = currentSnapshot.rules
        rules.remove(at: index)
        return try commit(rules: rules, includeRules: currentSnapshot.includeRules)
    }

    func addIncluded(display: String) throws -> BlockedWordWriteResult {
        let rule = try BlockedWordCanonicalizer.rule(from: display)
        if currentSnapshot.includeRules.contains(where: { $0.normalizedKey == rule.normalizedKey }) {
            return .unchanged(reason: .duplicate, snapshot: currentSnapshot)
        }
        guard currentSnapshot.includeRules.count < BlockedWordCanonicalizer.maximumRuleCount else {
            throw BlockedWordValidationError.limitReached
        }
        return try commit(
            rules: currentSnapshot.rules,
            includeRules: currentSnapshot.includeRules + [rule]
        )
    }

    func updateIncluded(
        normalizedOld: String,
        newDisplay: String
    ) throws -> BlockedWordWriteResult {
        guard let index = currentSnapshot.includeRules.firstIndex(where: {
            $0.normalizedKey == normalizedOld
        }) else {
            throw BlockedWordValidationError.notFound
        }
        let replacement = try BlockedWordCanonicalizer.rule(from: newDisplay)
        if currentSnapshot.includeRules.enumerated().contains(where: {
            $0.offset != index && $0.element.normalizedKey == replacement.normalizedKey
        }) {
            throw BlockedWordValidationError.duplicateTarget
        }
        guard currentSnapshot.includeRules[index] != replacement else {
            return .unchanged(reason: .duplicate, snapshot: currentSnapshot)
        }
        var includeRules = currentSnapshot.includeRules
        includeRules[index] = replacement
        return try commit(rules: currentSnapshot.rules, includeRules: includeRules)
    }

    func removeIncluded(normalizedKey: String) throws -> BlockedWordWriteResult {
        guard let index = currentSnapshot.includeRules.firstIndex(where: { $0.normalizedKey == normalizedKey }) else {
            throw BlockedWordValidationError.notFound
        }
        var includeRules = currentSnapshot.includeRules
        includeRules.remove(at: index)
        return try commit(rules: currentSnapshot.rules, includeRules: includeRules)
    }

    func deleteAllBlocked() throws -> BlockedWordWriteResult {
        guard !currentSnapshot.rules.isEmpty else {
            return .unchanged(reason: .duplicate, snapshot: currentSnapshot)
        }
        return try commit(rules: [], includeRules: currentSnapshot.includeRules)
    }

    func deleteAllIncluded() throws -> BlockedWordWriteResult {
        guard !currentSnapshot.includeRules.isEmpty else {
            return .unchanged(reason: .duplicate, snapshot: currentSnapshot)
        }
        return try commit(rules: currentSnapshot.rules, includeRules: [])
    }

    func resetFilters() throws -> BlockedWordWriteResult {
        guard !currentSnapshot.rules.isEmpty || !currentSnapshot.includeRules.isEmpty else {
            return .unchanged(reason: .duplicate, snapshot: currentSnapshot)
        }
        return try commit(rules: [], includeRules: [])
    }


    private func commit(
        rules: [BlockedWordRule],
        includeRules: [BlockedWordRule]
    ) throws -> BlockedWordWriteResult {
        let next = BlockedWordSnapshot(
            revision: currentSnapshot.revision + 1,
            rules: rules,
            includeRules: includeRules
        )
        let data = try encoder.encode(
            Envelope(
                version: 1,
                revision: next.revision,
                rules: next.rules,
                includeRules: next.includeRules
            )
        )
        defaults.set(data, forKey: Self.wordsKey)
        currentSnapshot = next
        return .changed(next)
    }
}
