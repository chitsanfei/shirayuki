import Foundation

nonisolated struct ReaderProgress: Codable, Sendable, Equatable {
    let comicId: String
    let chapterId: String
    let chapterTitle: String
    let chapterOrder: Int
    let pageIndex: Int
    let updatedAt: Date
}

@MainActor
final class ReaderProgressStore {
    static let shared = ReaderProgressStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "reader_progress_records"

    private init() {}

    func progress(for comicId: String) -> ReaderProgress? {
        loadProgressMap()[comicId]
    }

    func save(
        comicId: String,
        chapterId: String,
        chapterTitle: String,
        chapterOrder: Int,
        pageIndex: Int
    ) {
        var progressMap = loadProgressMap()
        progressMap[comicId] = ReaderProgress(
            comicId: comicId,
            chapterId: chapterId,
            chapterTitle: chapterTitle,
            chapterOrder: chapterOrder,
            pageIndex: pageIndex,
            updatedAt: Date()
        )
        persist(progressMap)
    }

    func clearProgress(for comicId: String) {
        var progressMap = loadProgressMap()
        progressMap.removeValue(forKey: comicId)
        persist(progressMap)
    }

    private func loadProgressMap() -> [String: ReaderProgress] {
        guard let data = defaults.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: ReaderProgress].self, from: data)) ?? [:]
    }

    private func persist(_ progressMap: [String: ReaderProgress]) {
        guard let data = try? JSONEncoder().encode(progressMap) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
