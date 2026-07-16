import Foundation
import CryptoKit

nonisolated struct OfflineImageRecord: Codable, Sendable, Identifiable {
    let id: String
    let url: String
    let fileName: String
    let byteCount: Int
}

nonisolated struct OfflineChapterRecord: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let order: Int
    let quality: AppImageQuality
    let images: [OfflineImageRecord]
}

nonisolated struct OfflineComicRecord: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let thumbURL: String
    let createdAt: String
    let updatedAt: String
    let downloadedAt: Date
    let quality: AppImageQuality
    let chapters: [OfflineChapterRecord]

    var imageCount: Int {
        chapters.reduce(0) { $0 + $1.images.count }
    }

    var byteCount: Int {
        chapters.reduce(0) { $0 + $1.images.reduce(0) { $0 + $1.byteCount } }
    }
}

nonisolated struct OfflineDownloadProgress: Sendable {
    let completedImages: Int
    let totalImages: Int
}

nonisolated enum OfflineImageSource: Sendable, Equatable {
    case none
    case offline
    case online
}

actor OfflineComicStore {
    static let shared = OfflineComicStore()

    private let rootDirectory: URL
    private let fileManager = FileManager.default

    private init() {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        rootDirectory = applicationSupport.appendingPathComponent("OfflineComics", isDirectory: true)
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    func allComics() -> [OfflineComicRecord] {
        guard let directories = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return directories.compactMap(loadRecord(at:)).sorted { $0.downloadedAt > $1.downloadedAt }
    }

    func record(for comicID: String) -> OfflineComicRecord? {
        loadRecord(at: directory(for: comicID))
    }

    func storageSize() -> Int {
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return enumerator.reduce(0) { total, item in
            guard let url = item as? URL else { return total }
            return total + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    func imageData(
        comicID: String,
        chapterID: String,
        url: String,
        quality: AppImageQuality,
        expectedImageCount: Int?
    ) -> Data? {
        guard let chapter = record(for: comicID)?.chapters.first(where: { $0.id == chapterID }),
              chapter.quality.isAtLeast(quality),
              expectedImageCount == nil || chapter.images.count == expectedImageCount,
              let image = chapter.images.first(where: { $0.url == url }) else { return nil }
        return try? Data(contentsOf: directory(for: comicID).appendingPathComponent(image.fileName))
    }

    func source(
        comicID: String,
        chapterID: String,
        quality: AppImageQuality,
        expectedImageCount: Int
    ) -> OfflineImageSource {
        guard let chapter = record(for: comicID)?.chapters.first(where: { $0.id == chapterID }) else { return .none }
        guard chapter.quality.isAtLeast(quality), chapter.images.count == expectedImageCount else { return .online }
        return .offline
    }

    func offlineChapterImages(comicID: String, chapterID: String, quality: AppImageQuality) -> [OfflineImageRecord]? {
        guard let chapter = record(for: comicID)?.chapters.first(where: { $0.id == chapterID }),
              chapter.quality.isAtLeast(quality) else { return nil }
        return chapter.images
    }

    func offlineChapter(comicID: String, chapterID: String, quality: AppImageQuality) -> OfflineChapterRecord? {
        guard let chapter = record(for: comicID)?.chapters.first(where: { $0.id == chapterID }),
              chapter.quality.isAtLeast(quality) else { return nil }
        return chapter
    }

    func download(
        comicID: String,
        title: String,
        thumbURL: String,
        createdAt: String,
        updatedAt: String,
        chapters: [PicaChapter],
        quality: AppImageQuality,
        progress: (OfflineDownloadProgress) -> Void = { _ in }
    ) async throws {
        guard !chapters.isEmpty else { return }
        let finalDirectory = directory(for: comicID)
        let hadExistingRecord = loadRecord(at: finalDirectory) != nil
        var didPersistChapter = false
        var completedImages = 0
        var totalImages = 0
        progress(OfflineDownloadProgress(completedImages: 0, totalImages: 0))
        try fileManager.createDirectory(at: finalDirectory, withIntermediateDirectories: true)

        do {
            for chapter in chapters {
                try Task.checkCancellation()
                let (images, titleFromServer) = try await PicaAPIService.shared.fetchChapterImages(id: comicID, order: chapter.order)
                totalImages += images.count
                progress(OfflineDownloadProgress(completedImages: completedImages, totalImages: totalImages))
                var storedImages: [OfflineImageRecord] = []
                var writtenFileNames: [String] = []
                do {
                    for (imageIndex, image) in images.enumerated() {
                        try Task.checkCancellation()
                        guard let data = try await ImageLoader.shared.loadImage(from: image.url, quality: quality) else {
                            throw URLError(.cannotDecodeContentData)
                        }
                        let fileName = "\(directoryName(for: chapter.id))_\(UUID().uuidString)_\(imageIndex).data"
                        try data.write(to: finalDirectory.appendingPathComponent(fileName), options: .atomic)
                        writtenFileNames.append(fileName)
                        storedImages.append(
                            OfflineImageRecord(
                                id: image.uid,
                                url: image.url,
                                fileName: fileName,
                                byteCount: data.count
                            )
                        )
                        completedImages += 1
                        progress(OfflineDownloadProgress(completedImages: completedImages, totalImages: totalImages))
                    }

                    let offlineChapter = OfflineChapterRecord(
                        id: chapter.id,
                        title: titleFromServer.isEmpty ? chapter.title : titleFromServer,
                        order: chapter.order,
                        quality: quality,
                        images: storedImages
                    )
                    try persistChapter(
                        offlineChapter,
                        comicID: comicID,
                        title: title,
                        thumbURL: thumbURL,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        quality: quality,
                        directory: finalDirectory
                    )
                    didPersistChapter = true
                    for image in images {
                        await ImageLoader.shared.removeCachedImage(from: image.url, quality: quality)
                    }
                } catch {
                    for fileName in writtenFileNames {
                        try? fileManager.removeItem(at: finalDirectory.appendingPathComponent(fileName))
                    }
                    throw error
                }
            }
        } catch {
            if !hadExistingRecord && !didPersistChapter {
                try? fileManager.removeItem(at: finalDirectory)
            }
            throw error
        }
    }

    private func persistChapter(
        _ chapter: OfflineChapterRecord,
        comicID: String,
        title: String,
        thumbURL: String,
        createdAt: String,
        updatedAt: String,
        quality: AppImageQuality,
        directory: URL
    ) throws {
        let existingRecord = loadRecord(at: directory)
        var chapters = existingRecord?.chapters ?? []
        let previousChapter = chapters.first { $0.id == chapter.id }
        if let index = chapters.firstIndex(where: { $0.id == chapter.id }) {
            chapters[index] = chapter
        } else {
            chapters.append(chapter)
        }

        let record = OfflineComicRecord(
            id: comicID,
            title: title,
            thumbURL: thumbURL,
            createdAt: createdAt,
            updatedAt: updatedAt,
            downloadedAt: Date(),
            quality: quality,
            chapters: chapters.sorted { $0.order < $1.order }
        )
        try JSONEncoder().encode(record).write(
            to: directory.appendingPathComponent("metadata.json"),
            options: .atomic
        )

        if let previousChapter {
            let currentFileNames = Set(chapter.images.map(\.fileName))
            for image in previousChapter.images where !currentFileNames.contains(image.fileName) {
                try? fileManager.removeItem(at: directory.appendingPathComponent(image.fileName))
            }
        }
    }

    func delete(comicID: String) throws {
        try fileManager.removeItem(at: directory(for: comicID))
    }

    func deleteAll() throws {
        try fileManager.removeItem(at: rootDirectory)
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    private func loadRecord(at directory: URL) -> OfflineComicRecord? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("metadata.json")) else { return nil }
        return try? JSONDecoder().decode(OfflineComicRecord.self, from: data)
    }

    private func directory(for comicID: String) -> URL {
        rootDirectory.appendingPathComponent(directoryName(for: comicID), isDirectory: true)
    }

    private func directoryName(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
