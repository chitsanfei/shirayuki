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
final class ReaderViewModel: ObservableObject {
    @Published var comic: ComicDetail
    @Published var chapters: [PicaChapter] = []
    @Published var currentChapterIndex: Int = 0
    @Published var images: [ChapterImage] = []
    @Published var currentPageIndex: Int = 0 {
        didSet {
            scheduleProgressPersistence()
        }
    }
    @Published var currentChapterTitle: String = ""
    @Published var readMode: ReadMode = .vertical {
        didSet {
            scrollTargetPage = currentPageIndex
        }
    }
    @Published var showToolbar = false
    @Published var showPageNumbers = true
    @Published var isMenuLocked = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAutoTurning = false
    @Published var autoTurnInterval: Double = 5
    @Published var scrollTargetPage: Int?
    
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
        initialPageIndex: Int = 0
    ) {
        self.comic = comic
        self.initialChapters = initialChapters
        self.initialChapterIndex = initialChapterIndex
        self.initialChapterId = initialChapterId
        self.initialChapterOrder = initialChapterOrder
        self.initialPageIndex = initialPageIndex
    }

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
            errorMessage = error.localizedDescription
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
        
        do {
            let (imgs, title) = try await PicaAPIService.shared.fetchChapterImages(
                id: comic.id,
                order: order
            )
            images = imgs
            currentChapterTitle = title
            let clampedPage = min(max(startingPage, 0), max(0, imgs.count - 1))
            currentPageIndex = clampedPage
            scrollTargetPage = imgs.isEmpty ? nil : clampedPage
            preloadAdjacentImages()
            return true
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            stopAutoTurn()
            errorMessage = error.localizedDescription
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
        guard !images.isEmpty else { return }
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
        if let initialChapterId,
           let matchedIndex = chapters.firstIndex(where: { $0.id == initialChapterId }) {
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
}
