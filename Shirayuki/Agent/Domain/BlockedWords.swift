import Foundation

nonisolated struct BlockedWordRule: Codable, Equatable, Sendable {
    let displayValue: String
    let normalizedKey: String
}

nonisolated struct BlockedWordSnapshot: Codable, Equatable, Sendable {
    let revision: UInt64
    let rules: [BlockedWordRule]
    let includeRules: [BlockedWordRule]

    init(revision: UInt64, rules: [BlockedWordRule], includeRules: [BlockedWordRule] = []) {
        self.revision = revision
        self.rules = rules
        self.includeRules = includeRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        revision = try container.decode(UInt64.self, forKey: .revision)
        rules = try container.decode([BlockedWordRule].self, forKey: .rules)
        includeRules = try container.decodeIfPresent([BlockedWordRule].self, forKey: .includeRules) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case revision, rules, includeRules
    }

    static let empty = BlockedWordSnapshot(revision: 0, rules: [])
}

nonisolated enum BlockedWordUnchangedReason: String, Codable, Equatable, Sendable {
    case duplicate
}

nonisolated enum BlockedWordWriteResult: Equatable, Sendable {
    case changed(BlockedWordSnapshot)
    case unchanged(reason: BlockedWordUnchangedReason, snapshot: BlockedWordSnapshot)

    var snapshot: BlockedWordSnapshot {
        switch self {
        case let .changed(snapshot), let .unchanged(_, snapshot): snapshot
        }
    }
}

nonisolated enum BlockedWordValidationError: String, Error, Codable, Equatable, Sendable {
    case empty
    case controlCharacter = "control_character"
    case tooLong = "too_long"
    case limitReached = "limit_reached"
    case notFound = "not_found"
    case duplicateTarget = "duplicate_target"
}

nonisolated enum BlockedWordCanonicalizer {
    static let maximumRuleCount = 100
    static let maximumDisplayLength = 64
    private static let locale = Locale(identifier: "en_US_POSIX")

    static func rule(from input: String) throws -> BlockedWordRule {
        let displayValue = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayValue.isEmpty else { throw BlockedWordValidationError.empty }
        guard displayValue.count <= maximumDisplayLength else {
            throw BlockedWordValidationError.tooLong
        }
        guard !displayValue.unicodeScalars.contains(where: {
            $0.properties.generalCategory == .control || CharacterSet.controlCharacters.contains($0)
        }) else {
            throw BlockedWordValidationError.controlCharacter
        }

        return BlockedWordRule(displayValue: displayValue, normalizedKey: normalize(displayValue))
    }

    static func normalize(_ value: String) -> String {
        value.precomposedStringWithCompatibilityMapping.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: locale
        )
    }
}

nonisolated enum BlockedWordMatcher {
    static func matches(fields: some Sequence<String>, snapshot: BlockedWordSnapshot) -> Bool {
        guard !snapshot.rules.isEmpty else { return false }
        return fields.lazy.map(BlockedWordCanonicalizer.normalize).contains { field in
            snapshot.rules.contains { field.contains($0.normalizedKey) }
        }
    }
    static func isVisible(fields: some Sequence<String>, snapshot: BlockedWordSnapshot) -> Bool {
        let values = fields.map(BlockedWordCanonicalizer.normalize)
        guard !values.contains(where: { field in
            snapshot.rules.contains { field.contains($0.normalizedKey) }
        }) else { return false }
        return snapshot.includeRules.isEmpty
            || values.contains { field in
                snapshot.includeRules.contains { field.contains($0.normalizedKey) }
            }
    }
}

protocol BlockedWordRepository: Sendable {
    func snapshot() async -> BlockedWordSnapshot
    func add(display: String) async throws -> BlockedWordWriteResult
    func update(normalizedOld: String, newDisplay: String) async throws -> BlockedWordWriteResult
    func remove(normalizedKey: String) async throws -> BlockedWordWriteResult
}
