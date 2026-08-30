import Foundation

nonisolated struct AgentToolCatalog: AgentToolCallParsing {
    private struct Spec: Sendable {
        let definition: AgentToolDefinition
        let allowedKeys: Set<String>
        let requiredKeys: Set<String>
        let decode: @Sendable (AgentLLMToolCall) throws -> AgentCommand
    }

    private let specs: [String: Spec]
    let definitions: [AgentToolDefinition]

    init() {
        let values = Self.makeSpecs()
        specs = Dictionary(uniqueKeysWithValues: values.map { ($0.definition.name, $0) })
        definitions = values.map(\.definition)
    }

    func parse(_ call: AgentLLMToolCall) -> Result<AgentParsedToolCall, AgentToolParseError> {
        do {
            let callID = try Self.identifier(call.id)
            guard let spec = specs[call.name] else { throw AgentToolParseError.unknownTool }
            let object = try Self.object(call.arguments)
            let keys = Set(object.keys)
            guard keys.isSubset(of: spec.allowedKeys) else { throw AgentToolParseError.unknownArgument }
            guard spec.requiredKeys.isSubset(of: keys) else { throw AgentToolParseError.missingArgument }
            return .success(.init(callID: callID, command: try spec.decode(call)))
        } catch let error as AgentToolParseError {
            return .failure(error)
        } catch {
            return .failure(Self.map(error))
        }
    }

    private static func makeSpecs() -> [Spec] {
        let emptySchema = #"{"type":"object","properties":{},"additionalProperties":false}"#
        return [
            empty("currentContext", schema: emptySchema, command: .currentContext),
            empty("currentUser", schema: emptySchema, command: .currentUser),
            empty("offlineLibrary", schema: emptySchema, command: .offlineLibrary),
            empty("currentPageContent", schema: emptySchema, command: .currentPageContent),
            empty("listBlockedWords", schema: emptySchema, command: .listBlockedWords),
            empty("listIncludedWords", schema: emptySchema, command: .listIncludedWords),
            spec(
                "favoritePage",
                schema: #"{"type":"object","properties":{"page":{"type":"integer","minimum":1,"maximum":100},"sort":{"type":"string","enum":["dd","da","ld","vd"]}},"additionalProperties":false}"#,
                allowed: ["page", "sort"]
            ) { call in
                let value: FavoriteArguments = try decode(call)
                let page = value.page ?? 1
                guard (1...100).contains(page) else { throw AgentToolParseError.valueOutOfRange }
                return .favoritePage(page: page, sort: try sort(value.sort ?? "dd"))
            },
            spec(
                "downloadStatus",
                schema: #"{"type":"object","properties":{"job_id":{"type":"string","minLength":1,"maxLength":128}},"additionalProperties":false}"#,
                allowed: ["job_id"]
            ) { call in
                let value: DownloadStatusArguments = try decode(call)
                return .downloadStatus(jobID: try value.jobID.map(identifier))
            },
            spec(
                "search",
                schema: #"{"type":"object","properties":{"keyword":{"type":"string","minLength":1,"maxLength":100},"sort":{"type":"string","enum":["dd","da","ld","vd"]}},"required":["keyword"],"additionalProperties":false}"#,
                allowed: ["keyword", "sort"],
                required: ["keyword"]
            ) { call in
                let value: SearchArguments = try decode(call)
                let keyword = value.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !keyword.isEmpty else { throw AgentToolParseError.invalidValue }
                guard keyword.count <= 100 else { throw AgentToolParseError.valueOutOfRange }
                return .search(keyword: keyword, sort: try sort(value.sort ?? "dd"))
            },
            requiredID("openComic", wireKey: "comic_id") { .openComic(comicID: $0) },
            spec(
                "startReading",
                schema: #"{"type":"object","properties":{"comic_id":{"type":"string","minLength":1,"maxLength":128},"chapter_id":{"type":"string","minLength":1,"maxLength":128},"page_index":{"type":"integer","minimum":0}},"required":["comic_id"],"additionalProperties":false}"#,
                allowed: ["comic_id", "chapter_id", "page_index"],
                required: ["comic_id"]
            ) { call in
                let value: StartReadingArguments = try decode(call)
                guard value.pageIndex.map({ $0 >= 0 }) ?? true else { throw AgentToolParseError.valueOutOfRange }
                return .startReading(
                    comicID: try identifier(value.comicID),
                    chapterID: try value.chapterID.map(identifier),
                    pageIndex: value.pageIndex
                )
            },
            spec(
                "goToReaderPage",
                schema: #"{"type":"object","properties":{"page_index":{"type":"integer","minimum":0}},"required":["page_index"],"additionalProperties":false}"#,
                allowed: ["page_index"],
                required: ["page_index"]
            ) { call in
                let value: PageArguments = try decode(call)
                guard value.pageIndex >= 0 else { throw AgentToolParseError.valueOutOfRange }
                return .goToReaderPage(value.pageIndex)
            },
            spec(
                "goToReaderChapter",
                schema: #"{"type":"object","properties":{"chapter_id":{"type":"string","minLength":1,"maxLength":128},"page_index":{"type":"integer","minimum":0}},"required":["chapter_id"],"additionalProperties":false}"#,
                allowed: ["chapter_id", "page_index"],
                required: ["chapter_id"]
            ) { call in
                let value: ChapterArguments = try decode(call)
                guard value.pageIndex.map({ $0 >= 0 }) ?? true else { throw AgentToolParseError.valueOutOfRange }
                return .goToReaderChapter(
                    chapterID: try identifier(value.chapterID),
                    pageIndex: value.pageIndex
                )
            },
            spec(
                "startDownload",
                schema: #"{"type":"object","properties":{"comic_id":{"type":"string","minLength":1,"maxLength":128},"chapter_ids":{"type":"array","minItems":1,"maxItems":100,"uniqueItems":true,"items":{"type":"string","minLength":1,"maxLength":128}},"quality":{"type":"string","enum":["low","medium","high","original"]}},"required":["comic_id","chapter_ids","quality"],"additionalProperties":false}"#,
                allowed: ["comic_id", "chapter_ids", "quality"],
                required: ["comic_id", "chapter_ids", "quality"]
            ) { call in
                let value: DownloadArguments = try decode(call)
                guard (1...100).contains(value.chapterIDs.count) else { throw AgentToolParseError.valueOutOfRange }
                let chapterIDs = try value.chapterIDs.map(identifier)
                guard Set(chapterIDs).count == chapterIDs.count else { throw AgentToolParseError.invalidValue }
                guard let quality = AppImageQuality(rawValue: value.quality) else { throw AgentToolParseError.invalidValue }
                return .startDownload(
                    comicID: try identifier(value.comicID),
                    chapterIDs: chapterIDs,
                    quality: quality,
                    commandID: call.id
                )
            },
            requiredID("cancelDownload", wireKey: "job_id") {
                .cancelDownload(jobID: $0, commandID: "")
            },
            spec(
                "deleteOfflineComic",
                schema: #"{"type":"object","properties":{"comic_id":{"type":"string","minLength":1,"maxLength":128}},"required":["comic_id"],"additionalProperties":false}"#,
                allowed: ["comic_id"],
                required: ["comic_id"]
            ) { call in
                let object = try object(call.arguments)
                guard let comicID = object["comic_id"] as? String else {
                    throw AgentToolParseError.invalidType
                }
                return .deleteOfflineComic(
                    comicID: try identifier(comicID),
                    commandID: call.id
                )
            },
            desiredState("setLiked", booleanKey: "is_liked") { comicID, desired, callID in
                .setLiked(comicID: comicID, isLiked: desired, commandID: callID)
            },
            desiredState("setFavorited", booleanKey: "is_favorited") { comicID, desired, callID in
                .setFavorited(comicID: comicID, isFavorited: desired, commandID: callID)
            },
            wordMutation("addBlockedWord", keys: ["word"], required: ["word"], schema: #"{"type":"object","properties":{"word":{"type":"string","minLength":1,"maxLength":64}},"required":["word"],"additionalProperties":false}"#) { object, call in
                .addBlockedWord(word: try word(object, "word"), commandID: call.id)
            },
            wordMutation("updateBlockedWord", keys: ["old_word", "new_word"], required: ["old_word", "new_word"], schema: #"{"type":"object","properties":{"old_word":{"type":"string","minLength":1,"maxLength":64},"new_word":{"type":"string","minLength":1,"maxLength":64}},"required":["old_word","new_word"],"additionalProperties":false}"#) { object, call in
                .updateBlockedWord(
                    oldWord: try word(object, "old_word"),
                    newWord: try word(object, "new_word"),
                    commandID: call.id
                )
            },
            wordMutation("removeBlockedWord", keys: ["word"], required: ["word"], schema: #"{"type":"object","properties":{"word":{"type":"string","minLength":1,"maxLength":64}},"required":["word"],"additionalProperties":false}"#) { object, call in
                .removeBlockedWord(word: try word(object, "word"), commandID: call.id)
            },
            wordMutation("addIncludedWord", keys: ["word"], required: ["word"], schema: #"{"type":"object","properties":{"word":{"type":"string","minLength":1,"maxLength":64}},"required":["word"],"additionalProperties":false}"#) { object, call in
                .addIncludedWord(word: try word(object, "word"), commandID: call.id)
            },
            wordMutation("updateIncludedWord", keys: ["old_word", "new_word"], required: ["old_word", "new_word"], schema: #"{"type":"object","properties":{"old_word":{"type":"string","minLength":1,"maxLength":64},"new_word":{"type":"string","minLength":1,"maxLength":64}},"required":["old_word","new_word"],"additionalProperties":false}"#) { object, call in
                .updateIncludedWord(
                    oldWord: try word(object, "old_word"),
                    newWord: try word(object, "new_word"),
                    commandID: call.id
                )
            },
            wordMutation("removeIncludedWord", keys: ["word"], required: ["word"], schema: #"{"type":"object","properties":{"word":{"type":"string","minLength":1,"maxLength":64}},"required":["word"],"additionalProperties":false}"#) { object, call in
                .removeIncludedWord(word: try word(object, "word"), commandID: call.id)
            }
        ].map { spec in
            guard spec.definition.name != "cancelDownload" else {
                return Self.spec(
                    "cancelDownload",
                    schema: spec.definition.parametersJSON,
                    allowed: ["job_id"],
                    required: ["job_id"]
                ) { call in
                    let value: SingleIDArguments = try decode(call)
                    return .cancelDownload(jobID: try identifier(value.value), commandID: call.id)
                }
            }
            return spec
        }
    }

    private static func empty(_ name: String, schema: String, command: AgentCommand) -> Spec {
        spec(name, schema: schema, allowed: []) { call in
            let _: EmptyArguments = try decode(call)
            return command
        }
    }

    private static func requiredID(
        _ name: String,
        wireKey: String,
        command: @escaping @Sendable (String) -> AgentCommand
    ) -> Spec {
        let schema = "{\"type\":\"object\",\"properties\":{\"\(wireKey)\":{\"type\":\"string\",\"minLength\":1,\"maxLength\":128}},\"required\":[\"\(wireKey)\"],\"additionalProperties\":false}"
        return spec(name, schema: schema, allowed: [wireKey], required: [wireKey]) { call in
            let object = try object(call.arguments)
            guard let value = object[wireKey] as? String else { throw AgentToolParseError.invalidType }
            return command(try identifier(value))
        }
    }

    private static func desiredState(
        _ name: String,
        booleanKey: String,
        command: @escaping @Sendable (String, Bool, String) -> AgentCommand
    ) -> Spec {
        let schema = "{\"type\":\"object\",\"properties\":{\"comic_id\":{\"type\":\"string\",\"minLength\":1,\"maxLength\":128},\"\(booleanKey)\":{\"type\":\"boolean\"}},\"required\":[\"comic_id\",\"\(booleanKey)\"],\"additionalProperties\":false}"
        return spec(name, schema: schema, allowed: ["comic_id", booleanKey], required: ["comic_id", booleanKey]) { call in
            let object = try object(call.arguments)
            guard let comicID = object["comic_id"] as? String,
                  let desired = object[booleanKey] as? Bool else { throw AgentToolParseError.invalidType }
            return command(try identifier(comicID), desired, call.id)
        }
    }

    private static func wordMutation(
        _ name: String,
        keys: Set<String>,
        required: Set<String>,
        schema: String,
        command: @escaping @Sendable ([String: Any], AgentLLMToolCall) throws -> AgentCommand
    ) -> Spec {
        spec(name, schema: schema, allowed: keys, required: required) { call in
            try command(object(call.arguments), call)
        }
    }

    private static func spec(
        _ name: String,
        schema: String,
        allowed: Set<String>,
        required: Set<String> = [],
        decode: @escaping @Sendable (AgentLLMToolCall) throws -> AgentCommand
    ) -> Spec {
        Spec(
            definition: .init(name: name, description: "Shirayuki typed tool \(name).", parametersJSON: schema),
            allowedKeys: allowed,
            requiredKeys: required,
            decode: decode
        )
    }

    private static func object(_ arguments: String) throws -> [String: Any] {
        guard let data = arguments.data(using: .utf8) else { throw AgentToolParseError.invalidJSON }
        let value: Any
        do { value = try JSONSerialization.jsonObject(with: data) }
        catch { throw AgentToolParseError.invalidJSON }
        guard let object = value as? [String: Any] else { throw AgentToolParseError.invalidType }
        return object
    }

    private static func decode<T: Decodable>(_ call: AgentLLMToolCall) throws -> T {
        guard let data = call.arguments.data(using: .utf8) else { throw AgentToolParseError.invalidJSON }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw map(error) }
    }

    private static func identifier(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw AgentToolParseError.invalidValue }
        guard value.count <= 128 else { throw AgentToolParseError.valueOutOfRange }
        return value
    }

    private static func word(_ object: [String: Any], _ key: String) throws -> String {
        guard let raw = object[key] as? String else { throw AgentToolParseError.invalidType }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw AgentToolParseError.invalidValue }
        guard value.count <= 64 else { throw AgentToolParseError.valueOutOfRange }
        return value
    }

    private static func sort(_ raw: String) throws -> ComicSortType {
        guard let value = ComicSortType(rawValue: raw), ["dd", "da", "ld", "vd"].contains(raw) else {
            throw AgentToolParseError.invalidValue
        }
        return value
    }

    private static func map(_ error: Error) -> AgentToolParseError {
        guard let error = error as? DecodingError else { return .invalidJSON }
        switch error {
        case .keyNotFound: return .missingArgument
        case .typeMismatch, .valueNotFound: return .invalidType
        case .dataCorrupted: return .invalidValue
        @unknown default: return .invalidJSON
        }
    }
}

nonisolated private struct EmptyArguments: Decodable {}
nonisolated private struct FavoriteArguments: Decodable { let page: Int?; let sort: String? }
nonisolated private struct DownloadStatusArguments: Decodable {
    let jobID: String?
    enum CodingKeys: String, CodingKey { case jobID = "job_id" }
}
nonisolated private struct SearchArguments: Decodable { let keyword: String; let sort: String? }
nonisolated private struct StartReadingArguments: Decodable {
    let comicID: String
    let chapterID: String?
    let pageIndex: Int?
    enum CodingKeys: String, CodingKey {
        case comicID = "comic_id", chapterID = "chapter_id", pageIndex = "page_index"
    }
}
nonisolated private struct PageArguments: Decodable {
    let pageIndex: Int
    enum CodingKeys: String, CodingKey { case pageIndex = "page_index" }
}
nonisolated private struct ChapterArguments: Decodable {
    let chapterID: String
    let pageIndex: Int?
    enum CodingKeys: String, CodingKey { case chapterID = "chapter_id", pageIndex = "page_index" }
}
nonisolated private struct DownloadArguments: Decodable {
    let comicID: String
    let chapterIDs: [String]
    let quality: String
    enum CodingKeys: String, CodingKey {
        case comicID = "comic_id", chapterIDs = "chapter_ids", quality
    }
}
nonisolated private struct SingleIDArguments: Decodable {
    let value: String
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicIDKey.self)
        value = try container.decode(String.self, forKey: container.allKeys[0])
    }
}
nonisolated private struct DynamicIDKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
