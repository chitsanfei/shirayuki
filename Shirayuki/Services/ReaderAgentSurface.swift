import Foundation

@MainActor
protocol AgentReaderSurface: AnyObject {
    var agentReaderSnapshot: AgentReaderSnapshot { get }
    func agentGoToPage(_ index: Int)
    func agentGoToChapter(id: String, pageIndex: Int?) async -> Bool
    func agentCurrentPageData(capability: AgentPageCapability) async throws -> AgentImagePayload
    func agentPersistProgress()
}

@MainActor
extension ReaderViewModel: AgentReaderSurface {
    var agentReaderSnapshot: AgentReaderSnapshot {
        let chapter = currentChapter
        return AgentReaderSnapshot(
            comicID: comic.id,
            comicTitle: comic.title,
            chapterID: chapter?.id,
            chapterTitle: currentChapterTitle.isEmpty ? (chapter?.title ?? "") : currentChapterTitle,
            chapterOrder: chapter?.order,
            pageIndex: currentPageIndex,
            pageCount: images.count,
            source: offlineOnly ? .offline : (images.isEmpty ? .unavailable : .online),
            pageContentAvailable: images.indices.contains(currentPageIndex)
        )
    }

    func agentGoToPage(_ index: Int) {
        seekToPage(index)
    }

    func agentGoToChapter(id: String, pageIndex: Int?) async -> Bool {
        guard let index = chapters.firstIndex(where: { $0.id == id }) else { return false }
        await goToChapter(index, startingPage: pageIndex ?? 0)
        return currentChapter?.id == id && !images.isEmpty
    }

    func agentCurrentPageData(capability: AgentPageCapability) async throws -> AgentImagePayload {
        let chapter = currentChapter
        let fingerprint = "\(comic.id)|\(chapter?.id ?? "")|\(currentPageIndex)"
        guard capability.contextFingerprint == fingerprint,
              images.indices.contains(currentPageIndex),
              let chapter else {
            throw AgentImageError.unavailable
        }

        let imageURL = images[currentPageIndex].url
        let expectedCount = images.count
        let quality = imageQuality
        let data: Data?
        if offlineOnly {
            data = await OfflineComicStore.shared.imageData(
                comicID: comic.id,
                chapterID: chapter.id,
                url: imageURL,
                quality: quality,
                expectedImageCount: expectedCount
            )
        } else if !AppReaderSettingsStore.shared.ignoresOfflineContent,
                  let offlineData = await OfflineComicStore.shared.imageData(
                    comicID: comic.id,
                    chapterID: chapter.id,
                    url: imageURL,
                    quality: quality,
                    expectedImageCount: expectedCount
                  ) {
            data = offlineData
        } else {
            data = try await ImageLoader.shared.loadImage(from: imageURL, quality: quality)
        }

        guard let data else { throw AgentImageError.unavailable }
        return try AgentImageBudget.shared.prepare(data, capability: capability)
    }

    func agentPersistProgress() {
        persistProgressNow()
    }
}
