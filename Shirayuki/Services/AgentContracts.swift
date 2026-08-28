import Foundation

// MARK: - Startup and page context

/// Distinct startup phases presented while the session is being prepared.
nonisolated enum StartupLoadingPhase: String, Equatable, Sendable {
    case preparing
    case validatingSession
    case restoringCredentials
    case loadingProfile
}

/// Explicit startup lifecycle consumed by the root UI.
nonisolated enum StartupState: Equatable, Sendable {
    case loading(StartupLoadingPhase)
    case readyAuthenticated
    case readyUnauthenticated
    case failed(message: String)
}

/// Identifies the currently presented surface without retaining a View.
nonisolated indirect enum AgentPageContext: Equatable, Sendable {
    case startup(StartupLoadingPhase)
    case failed
    case login
    case tab(String)
    case detail(comicID: String)
    case offlineLibrary
    case reader(comicID: String, chapterID: String?, pageIndex: Int)
    case nonSettingsSheet(parent: AgentPageContext, kind: String)
}

nonisolated enum AgentPageKind: String, Equatable, Sendable {
    case startup
    case failed
    case login
    case tab
    case detail
    case offlineLibrary
    case reader
    case sheet
}

nonisolated enum AgentContentSource: String, Equatable, Sendable {
    case offline
    case online
    case unavailable
}

// MARK: - Redacted snapshots

nonisolated struct AgentPageSnapshot: Equatable, Sendable {
    let kind: AgentPageKind
    let title: String
    let comicID: String?
    let chapterID: String?
}

nonisolated struct AgentReaderSnapshot: Equatable, Sendable {
    let comicID: String
    let comicTitle: String
    let chapterID: String?
    let chapterTitle: String
    let chapterOrder: Int?
    let pageIndex: Int
    let pageCount: Int
    let source: AgentContentSource
    let pageContentAvailable: Bool
}

nonisolated struct AgentUserSnapshot: Equatable, Sendable {
    let displayName: String
    let level: Int
    let exp: Int
    let isPunched: Bool
    let favoriteCount: Int?
}

/// Minimal favorite item; it deliberately omits ComicSummary.thumb and other fields.
nonisolated struct AgentFavoriteItem: Equatable, Sendable, Identifiable {
    let comicID: String
    let title: String
    let author: String
    let chapterCount: Int
    let finished: Bool

    var id: String { comicID }

    init(
        comicID: String,
        title: String,
        author: String,
        chapterCount: Int,
        finished: Bool
    ) {
        self.comicID = comicID
        self.title = title
        self.author = author
        self.chapterCount = chapterCount
        self.finished = finished
    }

    init(_ summary: ComicSummary) {
        self.init(
            comicID: summary.id,
            title: summary.title,
            author: summary.author,
            chapterCount: summary.epsCount,
            finished: summary.finished
        )
    }
}

nonisolated struct AgentLibraryItem: Equatable, Sendable, Identifiable {
    let comicID: String
    let title: String
    let chapterCount: Int
    let imageCount: Int
    let quality: AppImageQuality
    let byteCount: Int
    let downloadedAt: Date
    init(
        comicID: String,
        title: String,
        chapterCount: Int,
        imageCount: Int,
        quality: AppImageQuality,
        byteCount: Int,
        downloadedAt: Date
    ) {
        self.comicID = comicID
        self.title = title
        self.chapterCount = chapterCount
        self.imageCount = imageCount
        self.quality = quality
        self.byteCount = byteCount
        self.downloadedAt = downloadedAt
    }


    var id: String { comicID }

    init(_ record: OfflineComicRecord) {
        comicID = record.id
        title = record.title
        chapterCount = record.chapters.count
        imageCount = record.imageCount
        quality = record.quality
        byteCount = record.byteCount
        downloadedAt = record.downloadedAt
    }
}

nonisolated struct AgentSearchItem: Equatable, Sendable, Identifiable {
    let comicID: String
    let title: String
    let author: String
    let chapterCount: Int
    let finished: Bool

    var id: String { comicID }

    init(_ summary: ComicSummary) {
        comicID = summary.id
        title = summary.title
        author = summary.author
        chapterCount = summary.epsCount
        finished = summary.finished
    }
}

nonisolated enum AgentDownloadState: String, Equatable, Sendable {
    case queued
    case downloading
    case completed
    case failed
    case cancelled
}

nonisolated struct AgentDownloadSnapshot: Equatable, Sendable, Identifiable {
    let id: String
    let comicID: String
    let title: String
    let chapterIDs: [String]
    let state: AgentDownloadState
    let completedImages: Int
    let totalImages: Int
    let errorMessage: String?
}

/// Base context sent at the start of a turn; providers are intentionally on-demand.
nonisolated struct AgentBaseSnapshot: Equatable, Sendable {
    let isLoggedIn: Bool
    let page: AgentPageSnapshot
    let reader: AgentReaderSnapshot?
}

// MARK: - Provider contracts

/// Capped offline-library data plus real aggregate counts.
nonisolated struct AgentOfflineLibrarySnapshot: Equatable, Sendable {
    static let defaultItemLimit = 100

    let items: [AgentLibraryItem]
    let totalCount: Int
    let storageBytes: Int

    var limitedItems: [AgentLibraryItem] {
        Array(items.prefix(Self.defaultItemLimit))
    }
}
nonisolated protocol AgentUserProvider: Sendable {
    func currentUser() async throws -> AgentUserSnapshot
}

nonisolated protocol AgentLibraryProvider: Sendable {
    func favoritePage(page: Int, sort: ComicSortType) async throws -> [AgentFavoriteItem]
    func offlineLibrary() async -> AgentOfflineLibrarySnapshot
}

nonisolated protocol AgentDownloadProvider: Sendable {
    func activeDownloads() async -> [AgentDownloadSnapshot]
    func snapshot(jobID: String) async throws -> AgentDownloadSnapshot
}

// MARK: - Prompt projections and commands

/// Names the exact projection sent for one command; no implicit global context exists.
nonisolated struct AgentPromptProjection: Equatable, Sendable {
    let commandName: String
    let allowedFields: [String]
    let excludedFields: [String]

    init(commandName: String, allowedFields: [String], excludedFields: [String]) {
        self.commandName = commandName
        self.allowedFields = allowedFields
        self.excludedFields = excludedFields
    }
}

/// Opaque one-turn capability issued only after one explicit user confirmation.
nonisolated struct AgentPageCapability: Equatable, Sendable {
    let turnID: String
    let nonce: String
    let contextFingerprint: String
    let providerKey: String

    init(turnID: String, nonce: String, contextFingerprint: String, providerKey: String) {
        self.turnID = turnID
        self.nonce = nonce
        self.contextFingerprint = contextFingerprint
        self.providerKey = providerKey
    }
}


nonisolated enum AgentCommand: Equatable, Sendable {
    case currentContext
    case currentUser
    case favoritePage(page: Int, sort: ComicSortType)
    case offlineLibrary
    case downloadStatus(jobID: String?)
    case search(keyword: String, sort: ComicSortType)
    case openComic(comicID: String)
    case startReading(comicID: String, chapterID: String?, pageIndex: Int?)
    case goToReaderPage(Int)
    case goToReaderChapter(chapterID: String, pageIndex: Int?)
    case currentPageContent
    case startDownload(comicID: String, chapterIDs: [String], quality: AppImageQuality)
    case cancelDownload(jobID: String, commandID: String)
    case setLiked(comicID: String, isLiked: Bool, commandID: String)
    case setFavorited(comicID: String, isFavorited: Bool, commandID: String)

    var name: String {
        switch self {
        case .currentContext: return "currentContext"
        case .currentUser: return "currentUser"
        case .favoritePage: return "favoritePage"
        case .offlineLibrary: return "offlineLibrary"
        case .downloadStatus: return "downloadStatus"
        case .search: return "search"
        case .openComic: return "openComic"
        case .startReading: return "startReading"
        case .goToReaderPage: return "goToReaderPage"
        case .goToReaderChapter: return "goToReaderChapter"
        case .currentPageContent: return "currentPageContent"
        case .startDownload: return "startDownload"
        case .cancelDownload: return "cancelDownload"
        case .setLiked: return "setLiked"
        case .setFavorited: return "setFavorited"
        }
    }
}

nonisolated enum AgentCommandError: Error, Equatable, Sendable {
    case loginRequired
    case contextUnavailable
    case capabilityRequired
    case configurationRequired
    case invalidPage
    case invalidIdentifier
    case pageImageUnavailable
    case pageImageTooLarge
    case pageImageRateLimited
    case downloadConflict(existingJobIDs: [String])
    case providerFailure
}

nonisolated enum AgentDesiredState: String, Equatable, Sendable {
    case liked
    case favorited
}

nonisolated enum AgentConfirmationPreview: Equatable, Sendable {
    case download(
        comicID: String,
        comicTitle: String,
        chapterTitles: [String],
        quality: AppImageQuality,
        estimatedPages: Int?
    )
    case cancelDownload(
        jobID: String,
        title: String,
        completedImages: Int,
        totalImages: Int,
        state: AgentDownloadState
    )
    case desiredState(
        comicID: String,
        comicTitle: String,
        action: AgentDesiredState,
        desired: Bool
    )
    case currentPage(providerHost: String)
}
nonisolated enum AgentCommandResult: Equatable, Sendable {

    case context(AgentBaseSnapshot)
    case user(AgentUserSnapshot)
    case favorites(items: [AgentFavoriteItem], page: Int, sort: ComicSortType)
    case offlineLibrary(items: [AgentLibraryItem], totalCount: Int, storageBytes: Int)
    case downloadStatus([AgentDownloadSnapshot])
    case search([AgentSearchItem])
    case openedComic(comicID: String)
    case startedReading(comicID: String, chapterID: String?, pageIndex: Int)
    case readerUpdated(AgentReaderSnapshot)
    case pageContent(AgentImagePayload)
    case queuedDownload(jobID: String)
    case cancelledDownload(jobID: String)
    case desiredStateApplied(comicID: String, isLiked: Bool?, isFavorited: Bool?)
    case requiresConfirmation(AgentConfirmationPreview)
    case loginRequired
    case capabilityRequired
    case configurationRequired
    case downloadConflict(existingJobIDs: [String])
    case failure(AgentCommandError)
}

// MARK: - Redaction helpers

nonisolated enum AgentRedactor {
    static func user(_ profile: UserProfileResponse, favoriteCount: Int? = nil) -> AgentUserSnapshot {
        AgentUserSnapshot(
            displayName: profile.name,
            level: profile.level,
            exp: profile.exp,
            isPunched: profile.isPunched,
            favoriteCount: favoriteCount
        )
    }

    static func promptProjection(for command: AgentCommand) -> AgentPromptProjection {
        let excluded = ["token", "password", "email", "birthday", "avatarURL", "filePath", "fileName", "rawURL", "rawJSON"]
        switch command {
        case .currentContext:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["pageContext", "title", "loginState", "readerSummary"], excludedFields: excluded)
        case .currentUser:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["displayName", "level", "exp", "isPunched", "favoriteCount"], excludedFields: excluded + ["favorites", "offlineLibrary", "downloads"])
        case .favoritePage:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["comicID", "title", "author", "chapterCount", "finished", "page", "sort"], excludedFields: excluded + ["thumb", "offlineLibrary", "downloads"])
        case .offlineLibrary:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["comicID", "title", "chapterCount", "imageCount", "quality", "byteCount", "downloadedAt", "totalCount", "storageBytes"], excludedFields: excluded + ["user", "favorites", "downloads"])
        case .downloadStatus:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["jobID", "comicID", "title", "chapterIDs", "state", "completedImages", "totalImages", "errorCode"], excludedFields: excluded + ["user", "favorites", "fullLibrary"])
        case .search:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["keyword", "sort", "comicID", "title", "author", "chapterCount", "finished"], excludedFields: excluded + ["thumb", "user", "favorites", "offlineLibrary", "downloads"])
        case .openComic, .startReading:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["comicID", "title", "chapterSummary", "pageContext"], excludedFields: excluded + ["user", "favorites", "offlineLibrary", "downloads"])
        case .goToReaderPage, .goToReaderChapter:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["readerSummary", "targetPage", "targetChapter"], excludedFields: excluded + ["user", "favorites", "offlineLibrary", "downloads", "imageData"])
        case .currentPageContent:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["readerSummary", "confirmedCurrentPageImage"], excludedFields: excluded + ["otherPages", "otherImages", "user", "favorites", "offlineLibrary", "downloads"])
        case .startDownload:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["comicID", "chapterIDs", "quality", "allowDownload"], excludedFields: excluded + ["user", "favorites", "fullLibrary", "unrelatedDownloads"])
        case .cancelDownload:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["jobID", "state"], excludedFields: excluded + ["user", "favorites", "fullLibrary"])
        case .setLiked, .setFavorited:
            return AgentPromptProjection(commandName: command.name, allowedFields: ["comicID", "desiredState", "knownCurrentState"], excludedFields: excluded + ["user", "favorites", "offlineLibrary", "downloads", "imageData"])
        }
    }
}
 
/// Projects one typed result into the minimum safe text sent to the language model.
nonisolated enum AgentResultProjector {
    static func project(_ result: AgentCommandResult, for command: AgentCommand) -> String? {
        switch (command, result) {
        case (.currentContext, let .context(value)):
            return "kind=\(value.page.kind.rawValue); title=\(value.page.title); comicID=\(value.page.comicID ?? "none"); chapterID=\(value.page.chapterID ?? "none"); loggedIn=\(value.isLoggedIn)"
        case (.currentUser, let .user(value)):
            return "displayName=\(value.displayName); level=\(value.level); exp=\(value.exp); isPunched=\(value.isPunched); favoriteCount=\(value.favoriteCount.map(String.init) ?? "none")"
        case (.favoritePage, let .favorites(items, page, sort)):
            let items = items.prefix(20).map {
                "comicID=\($0.comicID); title=\($0.title); author=\($0.author); chapterCount=\($0.chapterCount); finished=\($0.finished)"
            }.joined(separator: "\n")
            return "page=\(page); sort=\(sort.rawValue)\n\(items)"
        case (.offlineLibrary, let .offlineLibrary(items, totalCount, storageBytes)):
            let items = items.prefix(20).map {
                "comicID=\($0.comicID); title=\($0.title); chapterCount=\($0.chapterCount); imageCount=\($0.imageCount); quality=\($0.quality.rawValue); byteCount=\($0.byteCount)"
            }.joined(separator: "\n")
            return "totalCount=\(totalCount); storageBytes=\(storageBytes)\n\(items)"
        case (.downloadStatus, let .downloadStatus(items)):
            return items.map {
                "jobID=\($0.id); comicID=\($0.comicID); title=\($0.title); state=\($0.state.rawValue); progress=\($0.completedImages)/\($0.totalImages)"
            }.joined(separator: "\n")
        case (.search, let .search(items)):
            return items.prefix(20).map {
                "comicID=\($0.comicID); title=\($0.title); author=\($0.author); chapterCount=\($0.chapterCount); finished=\($0.finished)"
            }.joined(separator: "\n")
        case (.openComic, let .openedComic(comicID)):
            return "comicID=\(comicID); opened=true"
        case (.startReading, let .startedReading(comicID, chapterID, pageIndex)):
            return "comicID=\(comicID); chapterID=\(chapterID ?? "none"); pageIndex=\(pageIndex)"
        case (.goToReaderPage, let .readerUpdated(value)),
             (.goToReaderChapter, let .readerUpdated(value)):
            return "comicID=\(value.comicID); chapterID=\(value.chapterID ?? "none"); pageIndex=\(value.pageIndex); pageCount=\(value.pageCount)"
        case (.startDownload, let .queuedDownload(jobID)):
            return "jobID=\(jobID); state=queued"
        case (.startDownload, let .downloadConflict(existingJobIDs)):
            return "state=conflict; existingJobIDs=\(existingJobIDs.joined(separator: ","))"
        case (.cancelDownload, let .cancelledDownload(jobID)):
            return "jobID=\(jobID); state=cancelled"
        case (.setLiked, let .desiredStateApplied(comicID, isLiked, _)):
            return "comicID=\(comicID); isLiked=\(isLiked.map(String.init) ?? "none")"
        case (.setFavorited, let .desiredStateApplied(comicID, _, isFavorited)):
            return "comicID=\(comicID); isFavorited=\(isFavorited.map(String.init) ?? "none")"
        default:
            return nil
        }
    }
}
