import Foundation

actor DefaultAgentUserProvider: AgentUserProvider {
    func currentUser() async throws -> AgentUserSnapshot {
        AgentRedactor.user(try await PicaAPIService.shared.fetchUserProfile())
    }
}

actor DefaultAgentLibraryProvider: AgentLibraryProvider {
    func favoritePage(page: Int, sort: ComicSortType) async throws -> [AgentFavoriteItem] {
        guard (1...100).contains(page) else { throw AgentCommandError.invalidPage }
        let result = try await PicaAPIService.shared.fetchFavoriteComics(page: page, sort: sort)
        return result.docs.map(AgentFavoriteItem.init)
    }

    func offlineLibrary() async -> AgentOfflineLibrarySnapshot {
        let records = await OfflineComicStore.shared.allComics()
        return AgentOfflineLibrarySnapshot(
            items: Array(records.prefix(AgentOfflineLibrarySnapshot.defaultItemLimit).map(AgentLibraryItem.init)),
            totalCount: records.count,
            storageBytes: await OfflineComicStore.shared.storageSize()
        )
    }
}

actor DefaultAgentDownloadProvider: AgentDownloadProvider {
    func activeDownloads() async -> [AgentDownloadSnapshot] {
        await DownloadCoordinator.shared.activeSnapshots()
    }

    func snapshot(jobID: String) async throws -> AgentDownloadSnapshot {
        do {
            return try await DownloadCoordinator.shared.snapshot(jobID: jobID)
        } catch {
            throw AgentCommandError.invalidIdentifier
        }
    }
}

struct AgentPageCapabilityRegistry {
    private struct PendingCapability {
        let nonce: String
        let turnID: String
        let contextFingerprint: String
        let providerKey: String
        let expiresAt: Date
    }

    private var pending: [String: PendingCapability] = [:]
    private var consumedNonces = Set<String>()

    mutating func issue(_ capability: AgentPageCapability, expiresAt: Date) {
        consumedNonces.remove(capability.nonce)
        pending[capability.nonce] = PendingCapability(
            nonce: capability.nonce,
            turnID: capability.turnID,
            contextFingerprint: capability.contextFingerprint,
            providerKey: capability.providerKey,
            expiresAt: expiresAt
        )
    }

    /// Atomically consumes a capability only when every live context field matches.
    @discardableResult
    mutating func consume(
        _ capability: AgentPageCapability,
        currentFingerprint: String,
        currentProviderKey: String,
        now: Date = Date()
    ) -> Bool {
        guard !consumedNonces.contains(capability.nonce),
              let stored = pending[capability.nonce],
              stored.turnID == capability.turnID,
              stored.contextFingerprint == capability.contextFingerprint,
              stored.providerKey == capability.providerKey,
              stored.contextFingerprint == currentFingerprint,
              stored.providerKey == currentProviderKey,
              stored.expiresAt > now else {
            return false
        }
        consumedNonces.insert(capability.nonce)
        return true
    }
}

/// Executes only typed, redacted Agent commands and keeps provider reads on demand.
@MainActor
final class AgentCommandService {
    static let shared = AgentCommandService()

    private let navigation: AppNavigationCoordinator
    private let userProvider: any AgentUserProvider
    private let libraryProvider: any AgentLibraryProvider
    private let downloadProvider: any AgentDownloadProvider
    private let chapterProvider: (String) async throws -> [PicaChapter]
    private let comicDetailProvider: (String) async throws -> ComicDetail
    private weak var readerSurface: (any AgentReaderSurface)?
    private var knownComicIDs = Set<String>()
    private var knownChapterIDs: [String: Set<String>] = [:]
    private var capabilityRegistry = AgentPageCapabilityRegistry()
    private var confirmedResults: [String: AgentCommandResult] = [:]
    private let sessionIsLoggedIn: () -> Bool

    init(
        navigation: AppNavigationCoordinator? = nil,
        userProvider: any AgentUserProvider = DefaultAgentUserProvider(),
        libraryProvider: any AgentLibraryProvider = DefaultAgentLibraryProvider(),
        downloadProvider: any AgentDownloadProvider = DefaultAgentDownloadProvider(),
        sessionIsLoggedIn: (() -> Bool)? = nil,
        chapterProvider: ((String) async throws -> [PicaChapter])? = nil,
        comicDetailProvider: ((String) async throws -> ComicDetail)? = nil
    ) {
        self.navigation = navigation ?? AppNavigationCoordinator.shared
        self.userProvider = userProvider
        self.libraryProvider = libraryProvider
        self.downloadProvider = downloadProvider
        self.chapterProvider = chapterProvider ?? { id in
            try await PicaAPIService.shared.fetchChapters(id: id)
        }
        self.comicDetailProvider = comicDetailProvider ?? { id in
            try await PicaAPIService.shared.fetchComicDetail(id: id)
        }
        self.sessionIsLoggedIn = sessionIsLoggedIn ?? { AppState.shared.isLoggedIn }
    }

    func registerReaderSurface(_ surface: any AgentReaderSurface) {
        readerSurface = surface
        knownComicIDs.insert(surface.agentReaderSnapshot.comicID)
    }

    func unregisterReaderSurface(_ surface: any AgentReaderSurface) {
        guard readerSurface === surface else { return }
        readerSurface = nil
    }

    /// Called by the UI only after the user confirms current-page sharing for this turn.
    func issuePageCapability(turnID: String) -> AgentPageCapability? {
        guard let reader = readerSurface else { return nil }
        let snapshot = reader.agentReaderSnapshot
        guard snapshot.pageContentAvailable,
              let chapterID = snapshot.chapterID else { return nil }
        let fingerprint = "\(snapshot.comicID)|\(chapterID)|\(snapshot.pageIndex)"
        let providerKey = currentProviderKey
        let capability = AgentPageCapability(
            turnID: turnID,
            nonce: UUID().uuidString,
            contextFingerprint: fingerprint,
            providerKey: providerKey
        )
        capabilityRegistry.issue(
            capability,
            expiresAt: Date().addingTimeInterval(60)
        )
        return capability
    }
    private var currentProviderKey: String {
        guard let configuration = LLMSettingsStore.shared.configuration else { return "unconfigured" }
        return "\(configuration.provider.rawValue)|\(configuration.baseURL.host?.lowercased() ?? "")|\(configuration.baseURL.port ?? 443)"
    }
 
    func currentPageConfirmationPreview() -> AgentConfirmationPreview? {
        guard let configuration = LLMSettingsStore.shared.configuration,
              let host = configuration.baseURL.host,
              !host.isEmpty else {
            return nil
        }
        let port = configuration.baseURL.port
        let displayHost = if let port, port != 443 {
            "\(host):\(port)"
        } else {
            host
        }
        return .currentPage(providerHost: displayHost)
    }


    func execute(
        _ command: AgentCommand,
        capability: AgentPageCapability? = nil,
        confirmed: Bool = false,
        turnID: String? = nil
    ) async -> AgentCommandResult {
        if let commandID = commandID(for: command), let previous = confirmedResults[commandID] {
            return previous
        }

        let result: AgentCommandResult
        switch command {
        case .currentContext:
            result = .context(baseSnapshot())
        case .currentUser:
            guard sessionIsLoggedIn() else { result = .loginRequired; break }
            do {
                result = .user(try await userProvider.currentUser())
            } catch {
                result = .failure(.providerFailure)
            }
        case let .favoritePage(page, sort):
            guard sessionIsLoggedIn() else { result = .loginRequired; break }
            guard (1...100).contains(page) else { result = .failure(.invalidPage); break }
            do {
                let items = try await libraryProvider.favoritePage(page: page, sort: sort)
                items.forEach { knownComicIDs.insert($0.comicID) }
                result = .favorites(items: items, page: page, sort: sort)
            } catch let error as AgentCommandError {
                result = .failure(error)
            } catch {
                result = .failure(.providerFailure)
            }
        case .offlineLibrary:
            let library = await libraryProvider.offlineLibrary()
            let items = library.limitedItems
            items.forEach { knownComicIDs.insert($0.comicID) }
            result = .offlineLibrary(
                items: items,
                totalCount: library.totalCount,
                storageBytes: library.storageBytes
            )
        case let .downloadStatus(jobID):
            do {
                if let jobID {
                    result = .downloadStatus([try await downloadProvider.snapshot(jobID: jobID)])
                } else {
                    result = .downloadStatus(await downloadProvider.activeDownloads())
                }
            } catch let error as AgentCommandError {
                result = .failure(error)
            } catch {
                result = .failure(.invalidIdentifier)
            }
        case let .search(keyword, sort):
            guard sessionIsLoggedIn() else { result = .loginRequired; break }
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 100 else { result = .failure(.invalidIdentifier); break }
            do {
                let response = try await PicaAPIService.shared.searchComics(keyword: trimmed, page: 1, sort: sort)
                response.docs.forEach { knownComicIDs.insert($0.id) }
                result = .search(response.docs.map(AgentSearchItem.init))
            } catch {
                result = .failure(.providerFailure)
            }
        case let .openComic(comicID):
            guard sessionIsLoggedIn() else { result = .loginRequired; break }
            guard knownComicIDs.contains(comicID) || currentComicID == comicID else {
                result = .failure(.invalidIdentifier)
                break
            }
            navigation.routeToComic(comicID)
            result = .openedComic(comicID: comicID)
        case let .startReading(comicID, chapterID, pageIndex):
            guard sessionIsLoggedIn() else { result = .loginRequired; break }
            guard knownComicIDs.contains(comicID) || currentComicID == comicID else {
                result = .failure(.invalidIdentifier)
                break
            }
            guard pageIndex.map({ $0 >= 0 }) ?? true else {
                result = .failure(.invalidPage)
                break
            }
            if let chapterID {
                do {
                    guard try await chapterIDs(for: comicID).contains(chapterID) else {
                        result = .failure(.invalidIdentifier)
                        break
                    }
                } catch {
                    result = .failure(.providerFailure)
                    break
                }
            }
            navigation.routeToReader(comicID: comicID, chapterID: chapterID, pageIndex: pageIndex)
            result = .startedReading(comicID: comicID, chapterID: chapterID, pageIndex: pageIndex ?? 0)
        case let .goToReaderPage(index):
            guard sessionIsLoggedIn() else { result = .loginRequired; break }
            guard index >= 0 else { result = .failure(.invalidPage); break }
            guard let reader = readerSurface else { result = .failure(.contextUnavailable); break }
            reader.agentGoToPage(index)
            result = .readerUpdated(reader.agentReaderSnapshot)
        case let .goToReaderChapter(chapterID, pageIndex):
            guard sessionIsLoggedIn() else { result = .loginRequired; break }
            guard pageIndex.map({ $0 >= 0 }) ?? true else {
                result = .failure(.invalidPage)
                break
            }
            guard let reader = readerSurface else { result = .failure(.contextUnavailable); break }
            guard await reader.agentGoToChapter(id: chapterID, pageIndex: pageIndex) else {
                result = .failure(.invalidIdentifier)
                break
            }
            result = .readerUpdated(reader.agentReaderSnapshot)
        case .currentPageContent:
            guard sessionIsLoggedIn() else { result = .loginRequired; break }
            guard LLMSettingsStore.shared.configuration != nil,
                  LLMSettingsStore.shared.hasAPIKey else {
                result = .configurationRequired
                break
            }
            guard let capability,
                  let turnID,
                  capability.turnID == turnID else {
                result = .capabilityRequired
                break
            }
            guard let reader = readerSurface else { result = .failure(.contextUnavailable); break }
            let snapshot = reader.agentReaderSnapshot
            let fingerprint = "\(snapshot.comicID)|\(snapshot.chapterID ?? "")|\(snapshot.pageIndex)"
            guard capabilityRegistry.consume(
                capability,
                currentFingerprint: fingerprint,
                currentProviderKey: currentProviderKey
            ) else {
                result = .capabilityRequired
                break
            }
            do {
                result = .pageContent(try await reader.agentCurrentPageData(capability: capability))
            } catch let error as AgentImageError {
                result = .failure(Self.mapImageError(error))
            } catch {
                result = .failure(.pageImageUnavailable)
            }
        case let .startDownload(comicID, chapterIDs, quality):
            guard sessionIsLoggedIn() else { result = .loginRequired; break }
            guard knownComicIDs.contains(comicID) || currentComicID == comicID else {
                result = .failure(.invalidIdentifier)
                break
            }
            if confirmed {
                result = await startDownload(comicID: comicID, chapterIDs: chapterIDs, quality: quality)
            } else {
                result = await downloadConfirmation(
                    comicID: comicID,
                    chapterIDs: chapterIDs,
                    quality: quality
                )
            }
        case let .cancelDownload(jobID, commandID):
            guard sessionIsLoggedIn() else { result = .loginRequired; break }
            if confirmed {
                do {
                    try await DownloadCoordinator.shared.cancel(jobID: jobID)
                    result = .cancelledDownload(jobID: jobID)
                    confirmedResults[commandID] = result
                } catch {
                    result = .failure(.invalidIdentifier)
                }
            } else {
                result = await cancellationConfirmation(jobID: jobID)
            }
        case let .setLiked(comicID, isLiked, commandID):
            result = await applyDesiredLike(comicID: comicID, desired: isLiked, commandID: commandID, confirmed: confirmed)
        case let .setFavorited(comicID, isFavorited, commandID):
            result = await applyDesiredFavorite(comicID: comicID, desired: isFavorited, commandID: commandID, confirmed: confirmed)
        }

        if let commandID = commandID(for: command), confirmed {
            confirmedResults[commandID] = result
            if confirmedResults.count > 256, let first = confirmedResults.keys.first {
                confirmedResults.removeValue(forKey: first)
            }
        }
        return result
    }

    private func baseSnapshot() -> AgentBaseSnapshot {
        let context = navigation.currentContext
        let page = AgentPageSnapshot(
            kind: Self.pageKind(for: context),
            title: Self.pageTitle(for: context),
            comicID: currentComicID,
            chapterID: readerSurface?.agentReaderSnapshot.chapterID
        )
        return AgentBaseSnapshot(
            isLoggedIn: sessionIsLoggedIn(),
            page: page,
            reader: readerSurface?.agentReaderSnapshot
        )
    }

    private var currentComicID: String? {
        switch navigation.currentContext {
        case let .detail(comicID), let .reader(comicID, _, _): return comicID
        default: return readerSurface?.agentReaderSnapshot.comicID
        }
    }

    private func chapterIDs(for comicID: String) async throws -> Set<String> {
        if let known = knownChapterIDs[comicID] {
            return known
        }
        let chapters = try await chapterProvider(comicID)
        let ids = Set(chapters.map(\.id))
        knownChapterIDs[comicID] = ids
        return ids
    }
    private func downloadConfirmation(
        comicID: String,
        chapterIDs: [String],
        quality: AppImageQuality
    ) async -> AgentCommandResult {
        guard !chapterIDs.isEmpty, Set(chapterIDs).count == chapterIDs.count else {
            return .failure(.invalidIdentifier)
        }
        do {
            let comic = try await comicDetailProvider(comicID)
            guard comic.allowDownload else { return .failure(.invalidIdentifier) }
            let chapters = try await chapterProvider(comicID)
            knownChapterIDs[comicID] = Set(chapters.map(\.id))
            guard chapterIDs.allSatisfy({ id in chapters.contains { $0.id == id } }) else {
                return .failure(.invalidIdentifier)
            }
            let selectedTitles = chapterIDs.compactMap { id in
                chapters.first { $0.id == id }?.title
            }
            return .requiresConfirmation(
                .download(
                    comicID: comic.id,
                    comicTitle: comic.title,
                    chapterTitles: selectedTitles,
                    quality: quality,
                    estimatedPages: comic.pagesCount > 0 ? comic.pagesCount : nil
                )
            )
        } catch {
            return .failure(.providerFailure)
        }
    }

    private func cancellationConfirmation(jobID: String) async -> AgentCommandResult {
        do {
            let snapshot = try await downloadProvider.snapshot(jobID: jobID)
            guard snapshot.state == .queued || snapshot.state == .downloading else {
                return .failure(.invalidIdentifier)
            }
            return .requiresConfirmation(
                .cancelDownload(
                    jobID: snapshot.id,
                    title: snapshot.title,
                    completedImages: snapshot.completedImages,
                    totalImages: snapshot.totalImages,
                    state: snapshot.state
                )
            )
        } catch {
            return .failure(.invalidIdentifier)
        }
    }

    private func desiredStateConfirmation(
        comicID: String,
        action: AgentDesiredState,
        desired: Bool
    ) async -> AgentCommandResult {
        do {
            let detail = try await comicDetailProvider(comicID)
            return .requiresConfirmation(
                .desiredState(
                    comicID: comicID,
                    comicTitle: detail.title,
                    action: action,
                    desired: desired
                )
            )
        } catch {
            return .failure(.providerFailure)
        }
    }

    private func startDownload(comicID: String, chapterIDs: [String], quality: AppImageQuality) async -> AgentCommandResult {
        guard !chapterIDs.isEmpty, Set(chapterIDs).count == chapterIDs.count else { return .failure(.invalidIdentifier) }
        do {
            let comic = try await comicDetailProvider(comicID)
            guard comic.allowDownload else { return .failure(.invalidIdentifier) }
            let chapters = try await chapterProvider(comicID)
            knownChapterIDs[comicID] = Set(chapters.map(\.id))
            guard chapterIDs.allSatisfy({ id in chapters.contains(where: { $0.id == id }) }) else {
                return .failure(.invalidIdentifier)
            }
            let selected = chapterIDs.compactMap { id in chapters.first(where: { $0.id == id }) }
            let request = DownloadRequest(
                comicID: comic.id,
                title: comic.title,
                thumbURL: comic.thumb.url,
                createdAt: comic.createdAt,
                updatedAt: comic.updatedAt,
                chapters: selected,
                quality: quality,
                allChapters: chapters,
                allowDownload: comic.allowDownload
            )
            return .queuedDownload(jobID: try await DownloadCoordinator.shared.start(request: request))
        } catch let error as DownloadCoordinatorError {
            if case let .conflict(existingJobIDs) = error {
                return .downloadConflict(existingJobIDs: existingJobIDs)
            }
            return .failure(.providerFailure)
        } catch {
            return .failure(.providerFailure)
        }
    }

    private func applyDesiredLike(comicID: String, desired: Bool, commandID: String, confirmed: Bool) async -> AgentCommandResult {
        guard sessionIsLoggedIn() else { return .loginRequired }
        guard knownComicIDs.contains(comicID) || currentComicID == comicID else { return .failure(.invalidIdentifier) }
        guard confirmed else {
            return await desiredStateConfirmation(comicID: comicID, action: .liked, desired: desired)
        }
        do {
            let detail = try await comicDetailProvider(comicID)
            if detail.isLiked != desired { _ = try await PicaAPIService.shared.likeComic(id: comicID) }
            let result: AgentCommandResult = .desiredStateApplied(comicID: comicID, isLiked: desired, isFavorited: nil)
            confirmedResults[commandID] = result
            return result
        } catch { return .failure(.providerFailure) }
    }

    private func applyDesiredFavorite(comicID: String, desired: Bool, commandID: String, confirmed: Bool) async -> AgentCommandResult {
        guard sessionIsLoggedIn() else { return .loginRequired }
        guard knownComicIDs.contains(comicID) || currentComicID == comicID else { return .failure(.invalidIdentifier) }
        guard confirmed else {
            return await desiredStateConfirmation(comicID: comicID, action: .favorited, desired: desired)
        }
        do {
            let detail = try await comicDetailProvider(comicID)
            if detail.isFavourite != desired { _ = try await PicaAPIService.shared.favoriteComic(id: comicID) }
            let result: AgentCommandResult = .desiredStateApplied(comicID: comicID, isLiked: nil, isFavorited: desired)
            confirmedResults[commandID] = result
            return result
        } catch { return .failure(.providerFailure) }
    }

    private func commandID(for command: AgentCommand) -> String? {
        switch command {
        case let .cancelDownload(_, commandID), let .setLiked(_, _, commandID), let .setFavorited(_, _, commandID): return commandID
        default: return nil
        }
    }

    private static func mapImageError(_ error: AgentImageError) -> AgentCommandError {
        switch error {
        case .unavailable, .unsupported: return .pageImageUnavailable
        case .tooLarge: return .pageImageTooLarge
        case .rateLimited: return .pageImageRateLimited
        }
    }

    private static func pageKind(for context: AgentPageContext) -> AgentPageKind {
        switch context {
        case .startup: return .startup
        case .failed: return .failed
        case .login: return .login
        case .tab: return .tab
        case .detail: return .detail
        case .offlineLibrary: return .offlineLibrary
        case .reader: return .reader
        case .nonSettingsSheet: return .sheet
        }
    }

    private static func pageTitle(for context: AgentPageContext) -> String {
        switch context {
        case let .startup(phase): return phase.rawValue
        case .failed: return "Failed"
        case .login: return "Login"
        case let .tab(tab): return tab
        case let .detail(comicID): return comicID
        case .offlineLibrary: return "Offline Library"
        case let .reader(_, chapterID, page): return "Reader \(chapterID ?? "") \(page + 1)"
        case let .nonSettingsSheet(_, kind): return kind
        }
    }
}
