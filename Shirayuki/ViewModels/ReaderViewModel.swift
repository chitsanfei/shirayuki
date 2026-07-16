import Foundation
import Combine
import SwiftUI

enum ReadMode: String, CaseIterable, Identifiable {
    case vertical = "vertical"
    case horizontal = "horizontal"
    
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .vertical: return AppLocalization.text("reader.mode.vertical")
        case .horizontal: return AppLocalization.text("reader.mode.horizontal")
        }
    }
}

@MainActor
final class ReaderViewModel: ObservableViewModel {
    @Published var comic: ComicDetail
    let offlineOnly: Bool
    @Published var chapters: [PicaChapter] = []
    @Published var currentChapterIndex: Int = 0
    @Published var images: [ChapterImage] = []
    @Published var currentPageIndex: Int = 0 {
        didSet {
            scheduleProgressPersistence()
        }
    }

    /// 由用户交互（滚动 / 翻页 / Slider）调用：只更新页码与进度副作用，不发起新的程序化滚动。
    func applyUserScrollPage(_ index: Int) {
        guard !images.isEmpty else { return }
        let clamped = min(max(index, 0), images.count - 1)
        if clamped != currentPageIndex {
            currentPageIndex = clamped
            preloadAdjacentImages()
            scheduleAutomaticDownloadIfNeeded()
        }
    }
    @Published var currentChapterTitle: String = ""
    @Published var readMode: ReadMode = .vertical {
        didSet {
            scrollTargetPage = currentPageIndex
            if readMode != oldValue {
                AppReaderSettingsStore.shared.setReadMode(readMode)
            }
        }
    }
    @Published var showToolbar = false
    @Published var showPageNumbers = true {
        didSet {
            if showPageNumbers != oldValue {
                AppReaderSettingsStore.shared.setShowPageNumbers(showPageNumbers)
            }
        }
    }
    @Published var isMenuLocked = false {
        didSet {
            if isMenuLocked != oldValue {
                AppReaderSettingsStore.shared.setMenuLocked(isMenuLocked)
            }
        }
    }
    @Published var imageQuality: AppImageQuality = AppImageQuality.stored {
        didSet {
            if imageQuality != oldValue {
                AppImageQualityStore.shared.setImageQuality(imageQuality)
            }
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAutoTurning = false
    @Published var autoTurnInterval: Double = 5 {
        didSet {
            if autoTurnInterval != oldValue {
                AppReaderSettingsStore.shared.setAutoTurnInterval(autoTurnInterval)
            }
        }
    }
    @Published var scrollTargetPage: Int?
    @Published var offlineSourceMessage: String?
    
    var currentChapter: PicaChapter? {
        guard currentChapterIndex < chapters.count else { return nil }
        return chapters[currentChapterIndex]
    }
    
    var isFirstChapter: Bool { currentChapterIndex == 0 }
    var isLastChapter: Bool { currentChapterIndex >= chapters.count - 1 }
    var isFirstPage: Bool { currentPageIndex == 0 }
    var isLastPage: Bool { currentPageIndex >= images.count - 1 }
    
    private var autoTurnTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?
    private var progressSaveTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    private var scheduledAutomaticDownloadChapterIDs = Set<String>()
    private let initialChapters: [PicaChapter]
    private let initialChapterIndex: Int
    private let initialChapterId: String?
    private let initialChapterOrder: Int?
    private let initialPageIndex: Int
    
    init(
        comic: ComicDetail,
        initialChapters: [PicaChapter] = [],
        initialChapterIndex: Int = 0,
        initialChapterId: String? = nil,
        initialChapterOrder: Int? = nil,
        initialPageIndex: Int = 0,
        offlineOnly: Bool = false
    ) {
        self.comic = comic
        self.offlineOnly = offlineOnly
        self.readMode = AppReaderSettingsStore.shared.readMode
        self.showPageNumbers = AppReaderSettingsStore.shared.showPageNumbers
        self.isMenuLocked = AppReaderSettingsStore.shared.isMenuLocked
        self.autoTurnInterval = AppReaderSettingsStore.shared.autoTurnInterval
        self.initialChapters = initialChapters
        self.initialChapterIndex = initialChapterIndex
        self.initialChapterId = initialChapterId
        self.initialChapterOrder = initialChapterOrder
        self.initialPageIndex = initialPageIndex
    }

    // deinit 在 @MainActor 类中是非 isolated 的，但只调用 Task.cancel()——
    // cancel 是 Sendable 且非隔离安全的方法，无需 main actor。这里有意不捕获其他可变状态。
    deinit {
        autoTurnTask?.cancel()
        initialLoadTask?.cancel()
        progressSaveTask?.cancel()
        preloadTask?.cancel()
    }

    func startInitialLoadIfNeeded() {
        guard chapters.isEmpty || images.isEmpty else { return }
        initialLoadTask?.cancel()
        initialLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.loadChapters()
        }
    }

    func retryInitialLoad() {
        errorMessage = nil
        currentChapterTitle = ""
        images = []
        currentPageIndex = 0
        scrollTargetPage = nil
        startInitialLoadIfNeeded()
    }

    func cancelOngoingWork() {
        persistProgressNow()
        initialLoadTask?.cancel()
        initialLoadTask = nil
        progressSaveTask?.cancel()
        progressSaveTask = nil
        preloadTask?.cancel()
        preloadTask = nil
        stopAutoTurn()
        isLoading = false
    }
    
    func loadChapters() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let loadedChapters = if initialChapters.isEmpty {
                try await PicaAPIService.shared.fetchChapters(id: comic.id)
            } else {
                initialChapters
            }
            
            chapters = loadedChapters.sorted { $0.order < $1.order }
            if !chapters.isEmpty {
                let startIndex = resolvedInitialChapterIndex(in: chapters)
                _ = await loadChapter(
                    at: startIndex,
                    startingPage: initialPageIndex,
                    shouldManageLoading: false
                )
            }
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            if (offlineOnly || !AppReaderSettingsStore.shared.ignoresOfflineContent),
               let record = await OfflineComicStore.shared.record(for: comic.id),
               !record.chapters.isEmpty {
                chapters = record.chapters.map {
                    PicaChapter(uid: $0.id, title: $0.title, order: $0.order, id: $0.id)
                }.sorted { $0.order < $1.order }
                announceOfflineSource(.offline)
                let startIndex = resolvedInitialChapterIndex(in: chapters)
                _ = await loadChapter(at: startIndex, startingPage: initialPageIndex, shouldManageLoading: false)
            } else {
                handleError(error)
            }
        }
    }

    @discardableResult
    func loadChapterImages(order: Int, startingPage: Int = 0, shouldManageLoading: Bool = true) async -> Bool {
        if shouldManageLoading {
            isLoading = true
        }
        errorMessage = nil
        defer {
            if shouldManageLoading {
                isLoading = false
            }
        }

        if offlineOnly,
           let chapterID = currentChapter?.id,
           let chapter = await OfflineComicStore.shared.offlineChapter(
               comicID: comic.id,
               chapterID: chapterID,
               quality: AppImageQuality.stored
           ) {
            images = chapter.images.map { ChapterImage(uid: $0.id, id: $0.id, offlineURL: $0.url) }
            currentChapterTitle = chapter.title
            currentPageIndex = min(max(startingPage, 0), max(0, images.count - 1))
            scrollTargetPage = images.isEmpty ? nil : currentPageIndex
            preloadAdjacentImages()
            announceOfflineSource(.offline)
            scheduleAutomaticDownloadIfNeeded()
            return true
        }
        
        do {
            let (imgs, title) = try await PicaAPIService.shared.fetchChapterImages(
                id: comic.id,
                order: order
            )
            let desiredQuality = AppImageQuality.stored
            let source: OfflineImageSource = (offlineOnly || !AppReaderSettingsStore.shared.ignoresOfflineContent)
                ? await OfflineComicStore.shared.source(
                    comicID: comic.id,
                    chapterID: currentChapter?.id ?? "",
                    quality: desiredQuality,
                    expectedImageCount: imgs.count
                )
                : .none

            if source == .offline,
               let chapter = await OfflineComicStore.shared.offlineChapter(
                   comicID: comic.id,
                   chapterID: currentChapter?.id ?? "",
                   quality: desiredQuality
               ) {
                images = chapter.images.map { ChapterImage(uid: $0.id, id: $0.id, offlineURL: $0.url) }
                currentChapterTitle = chapter.title
                announceOfflineSource(.offline)
            } else {
                images = imgs
                currentChapterTitle = title
                if source == .online {
                    announceOfflineSource(.online)
                }
            }
            let clampedPage = min(max(startingPage, 0), max(0, images.count - 1))
            currentPageIndex = clampedPage
            scrollTargetPage = images.isEmpty ? nil : clampedPage
            preloadAdjacentImages()
            scheduleAutomaticDownloadIfNeeded()
            return true
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            if (offlineOnly || !AppReaderSettingsStore.shared.ignoresOfflineContent),
               let chapterID = currentChapter?.id,
               let chapter = await OfflineComicStore.shared.offlineChapter(
                   comicID: comic.id,
                   chapterID: chapterID,
                   quality: AppImageQuality.stored
               ) {
                images = chapter.images.map { ChapterImage(uid: $0.id, id: $0.id, offlineURL: $0.url) }
                currentChapterTitle = chapter.title
                currentPageIndex = min(max(startingPage, 0), max(0, images.count - 1))
                scrollTargetPage = images.isEmpty ? nil : currentPageIndex
                announceOfflineSource(.offline)
                return true
            }
            stopAutoTurn()
            handleError(error)
        }
        return false
    }
    
    func goToChapter(_ index: Int, startingPage: Int = 0) async {
        guard index >= 0, index < chapters.count else { return }
        _ = await loadChapter(at: index, startingPage: startingPage)
    }
    
    func goNextChapter(startingPage: Int = 0) async {
        guard currentChapterIndex < chapters.count - 1 else { return }
        await goToChapter(currentChapterIndex + 1, startingPage: startingPage)
    }
    
    func goPreviousChapter(startingPage: Int = 0) async {
        guard currentChapterIndex > 0 else { return }
        await goToChapter(currentChapterIndex - 1, startingPage: startingPage)
    }
    
    func goNextPage() {
        Task {
            await advanceToNextPage()
        }
    }
    
    func goPreviousPage() {
        Task {
            await advanceToPreviousPage()
        }
    }
    
    func seekToPage(_ index: Int) {
        guard !images.isEmpty else { return }
        updateCurrentPage(to: index)
    }

    /// View 在程序化滚动（scrollTo）完成后调用，清空 scrollTargetPage 以避免重复消费。
    func consumeScrollTargetPage() {
        scrollTargetPage = nil
    }
    
    func toggleToolbar() {
        guard !isMenuLocked else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            showToolbar.toggle()
        }
    }
    
    func hideToolbar() {
        guard !isMenuLocked else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            showToolbar = false
        }
    }
    
    func startAutoTurn() {
        guard !images.isEmpty else { return }
        isAutoTurning = true
        autoTurnTask?.cancel()
        autoTurnTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isAutoTurning {
                try? await Task.sleep(nanoseconds: UInt64(self.autoTurnInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                guard self.isAutoTurning else { return }
                await self.advanceAutoTurnIfNeeded()
            }
        }
    }
    
    func stopAutoTurn() {
        isAutoTurning = false
        autoTurnTask?.cancel()
        autoTurnTask = nil
    }
    
    func toggleLockMenu() {
        isMenuLocked.toggle()
    }
    
    func preloadAdjacentImages() {
        guard !images.isEmpty, !offlineOnly else { return }
        let start = max(0, currentPageIndex - 1)
        let end = min(images.count - 1, currentPageIndex + 3)
        let urls = (start...end).map { images[$0].url }
        preloadTask?.cancel()
        preloadTask = Task(priority: .utility) {
            await ImageLoader.shared.preload(urls: urls)
        }
    }

    func persistProgressNow() {
        progressSaveTask?.cancel()
        progressSaveTask = nil
        persistProgressIfPossible()
    }

    private func loadChapter(
        at index: Int,
        startingPage: Int = 0,
        shouldManageLoading: Bool = true
    ) async -> Bool {
        guard index >= 0, index < chapters.count else { return false }

        let previousIndex = currentChapterIndex
        currentChapterIndex = index

        let didLoad = await loadChapterImages(
            order: chapters[index].order,
            startingPage: startingPage,
            shouldManageLoading: shouldManageLoading
        )

        if !didLoad {
            currentChapterIndex = previousIndex
        }

        return didLoad
    }

    func resolvedInitialChapterIndex(in chapters: [PicaChapter]) -> Int {
        let effectiveChapterId = initialChapterId?.isEmpty == false ? initialChapterId : nil
        if let effectiveChapterId,
           let matchedIndex = chapters.firstIndex(where: { $0.id == effectiveChapterId }) {
            return matchedIndex
        }

        if let initialChapterOrder,
           let matchedIndex = chapters.firstIndex(where: { $0.order == initialChapterOrder }) {
            return matchedIndex
        }

        return min(max(initialChapterIndex, 0), chapters.count - 1)
    }

    private func updateCurrentPage(to index: Int, shouldScroll: Bool = true) {
        guard !images.isEmpty else { return }
        let clampedIndex = min(max(index, 0), images.count - 1)
        currentPageIndex = clampedIndex
        if shouldScroll {
            scrollTargetPage = clampedIndex
        }
        preloadAdjacentImages()
        scheduleAutomaticDownloadIfNeeded()
    }

    private func advanceToNextPage() async {
        guard !isLoading, !images.isEmpty else { return }
        if currentPageIndex < images.count - 1 {
            updateCurrentPage(to: currentPageIndex + 1)
        } else if !isLastChapter {
            await goNextChapter()
        }
    }

    private func advanceToPreviousPage() async {
        guard !isLoading, !images.isEmpty else { return }
        if currentPageIndex > 0 {
            updateCurrentPage(to: currentPageIndex - 1)
        } else if !isFirstChapter {
            await goPreviousChapter(startingPage: .max)
        }
    }

    private func advanceAutoTurnIfNeeded() async {
        guard isAutoTurning else { return }
        guard !isLoading else { return }
        if currentPageIndex < images.count - 1 {
            updateCurrentPage(to: currentPageIndex + 1)
        } else if !isLastChapter {
            await goNextChapter()
        } else {
            stopAutoTurn()
        }
    }

    private func scheduleProgressPersistence() {
        progressSaveTask?.cancel()
        progressSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            self.persistProgressIfPossible()
        }
    }

    private func persistProgressIfPossible() {
        guard !images.isEmpty, let chapter = currentChapter else { return }
        let title = currentChapterTitle.isEmpty ? chapter.title : currentChapterTitle
        ReaderProgressStore.shared.save(
            comicId: comic.id,
            chapterId: chapter.id,
            chapterTitle: title,
            chapterOrder: chapter.order,
            pageIndex: currentPageIndex
        )
    }

    private func announceOfflineSource(_ source: OfflineImageSource) {
        let key: String?
        switch source {
        case .none:
            key = nil
        case .offline:
            key = "reader.offline.using"
        case .online:
            key = "reader.offline.usingOnline"
        }
        guard let key else { return }
        let message = AppLocalization.text(key)
        offlineSourceMessage = message
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self, self.offlineSourceMessage == message else { return }
            self.offlineSourceMessage = nil
        }
    }

    private func scheduleAutomaticDownloadIfNeeded() {
        guard !offlineOnly,
              !images.isEmpty,
              isLastPage,
              AppReaderSettingsStore.shared.downloadsWhileReading,
              let chapter = currentChapter,
              scheduledAutomaticDownloadChapterIDs.insert(chapter.id).inserted else { return }
        let comic = comic
        let quality = AppImageQuality.stored
        Task(priority: .utility) {
            try? await OfflineComicStore.shared.download(
                comicID: comic.id,
                title: comic.title,
                thumbURL: comic.thumb.url,
                createdAt: comic.createdAt,
                updatedAt: comic.updatedAt,
                chapters: [chapter],
                quality: quality
            )
        }
    }
}
