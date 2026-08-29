import Foundation
import XCTest
@testable import Shirayuki

private let agentTestSessionID = UUID()

final class AgentContractsTests: XCTestCase {
    func testFavoriteRedactionContainsOnlyAllowedFields() throws {
        let summary = try makeSummary()
        let item = AgentFavoriteItem(summary)
        XCTAssertEqual(item.comicID, "comic-1")
        XCTAssertEqual(item.title, "Comic")
        XCTAssertEqual(item.author, "Author")
        XCTAssertEqual(item.chapterCount, 4)
        XCTAssertTrue(item.finished)
    }

    func testPromptProjectionExcludesUnrequestedProviderData() {
        let projection = AgentRedactor.promptProjection(for: .currentUser)
        XCTAssertTrue(projection.allowedFields.contains("displayName"))
        XCTAssertTrue(projection.excludedFields.contains("favorites"))
        XCTAssertTrue(projection.excludedFields.contains("token"))
        XCTAssertFalse(projection.allowedFields.contains("thumb"))
    }

    func testDesiredStateCommandsAreDistinctAndIdempotencyCarriesCommandID() {
        let setLiked = AgentCommand.setLiked(comicID: "comic-1", isLiked: true, commandID: "command-1")
        let setUnliked = AgentCommand.setLiked(comicID: "comic-1", isLiked: false, commandID: "command-2")
        XCTAssertNotEqual(setLiked, setUnliked)
        XCTAssertEqual(setLiked.name, "setLiked")
    }

    func testStartupLoadingPhasesAreExplicit() {
        XCTAssertNotEqual(StartupState.loading(.preparing), StartupState.loading(.loadingProfile))
        XCTAssertEqual(StartupState.loading(.validatingSession), StartupState.loading(.validatingSession))
    }

    func testLLMEndpointRequiresHTTPSAndNoCredentialsInURL() {
        XCTAssertNotNil(LLMSettingsStore.validEndpoint("https://api.example.com/v1/chat/completions"))
        XCTAssertNil(LLMSettingsStore.validEndpoint("http://api.example.com/v1/chat/completions"))
        XCTAssertNil(LLMSettingsStore.validEndpoint("https://user:pass@api.example.com/v1"))
    }

    func testOriginPinRejectsDowngradeAndCrossOriginRedirects() {
        let source = URL(string: "https://api.example.com/v1")!
        XCTAssertTrue(OpenAIOriginPinningDelegate.allowsRedirect(from: source, to: URL(string: "https://api.example.com/v1/next")!))
        XCTAssertFalse(OpenAIOriginPinningDelegate.allowsRedirect(from: source, to: URL(string: "http://api.example.com/v1/next")!))
        XCTAssertFalse(OpenAIOriginPinningDelegate.allowsRedirect(from: source, to: URL(string: "https://other.example.com/v1/next")!))
    }
 
    func testVisionCapabilityRejectionMapsOnlyImageClientErrors() {
        XCTAssertTrue(OpenAIAgentTransport.isVisionCapabilityRejection(statusCode: 400, containsImage: true))
        XCTAssertTrue(OpenAIAgentTransport.isVisionCapabilityRejection(statusCode: 422, containsImage: true))
        XCTAssertFalse(OpenAIAgentTransport.isVisionCapabilityRejection(statusCode: 401, containsImage: true))
        XCTAssertFalse(OpenAIAgentTransport.isVisionCapabilityRejection(statusCode: 500, containsImage: true))
        XCTAssertFalse(OpenAIAgentTransport.isVisionCapabilityRejection(statusCode: 400, containsImage: false))
    }
    @MainActor
    func testSelectedTabIsAuthoritativeAndSurfaceRestoresParent() {
        let coordinator = AppNavigationCoordinator.shared
        coordinator.resetForTesting()
        defer { coordinator.resetForTesting() }
        coordinator.setRootContext(.tab(AppTab.home.rawValue))
        let offscreenSearch = coordinator.register(.tab(AppTab.search.rawValue))
        XCTAssertEqual(coordinator.currentContext, .tab(AppTab.home.rawValue))

        coordinator.setSelectedTab(AppTab.search.rawValue)
        XCTAssertEqual(coordinator.currentContext, .tab(AppTab.search.rawValue))

        let detail = coordinator.register(.detail(comicID: "comic-1"))
        XCTAssertEqual(coordinator.currentContext, .detail(comicID: "comic-1"))
        coordinator.unregister(detail)
        XCTAssertEqual(coordinator.currentContext, .tab(AppTab.search.rawValue))

        coordinator.unregister(offscreenSearch)
        XCTAssertEqual(coordinator.currentContext, .tab(AppTab.search.rawValue))
    }
 
    @MainActor
    func testVisibleBrowserContextOverridesRootAndRestoresAfterTabSwitch() {
        let coordinator = AppNavigationCoordinator.shared
        coordinator.resetForTesting()
        defer { coordinator.resetForTesting() }
        coordinator.setRootContext(.tab(AppTab.categories.rawValue))
        let browser = coordinator.register(.tab("browser:category:恋爱"))
        XCTAssertEqual(coordinator.currentContext, .tab("browser:category:恋爱"))

        coordinator.routeToComic("comic-7")
        XCTAssertEqual(coordinator.consumePendingComic(), "comic-7")

        coordinator.setSelectedTab(AppTab.profile.rawValue)
        XCTAssertEqual(coordinator.currentContext, .tab(AppTab.profile.rawValue))
        coordinator.setSelectedTab(AppTab.categories.rawValue)
        XCTAssertEqual(coordinator.currentContext, .tab("browser:category:恋爱"))
        coordinator.unregister(browser)
    }
 
    @MainActor
    func testReaderRouteIsRetainedUntilDetailConsumesIt() {
        let coordinator = AppNavigationCoordinator.shared
        coordinator.resetForTesting()
        defer { coordinator.resetForTesting() }

        coordinator.routeToReader(comicID: "comic-42", chapterID: "chapter-2", pageIndex: 7)
        XCTAssertEqual(
            coordinator.pendingReaderRequest,
            AgentReaderRequest(comicID: "comic-42", chapterID: "chapter-2", pageIndex: 7)
        )
        XCTAssertEqual(
            coordinator.consumePendingReaderRequest(),
            AgentReaderRequest(comicID: "comic-42", chapterID: "chapter-2", pageIndex: 7)
        )
        XCTAssertNil(coordinator.pendingReaderRequest)
    }
    @MainActor
    func testPageCapabilityRegistryIsOneTimeAndContextBound() {
        var registry = AgentPageCapabilityRegistry()
        let capability = AgentPageCapability(
            turnID: "turn-1",
            nonce: "nonce-1",
            contextFingerprint: "comic|chapter|0",
            providerKey: "openai|api.example.com|443"
        )
        let now = Date(timeIntervalSince1970: 100)
        registry.issue(capability, expiresAt: now.addingTimeInterval(30))
        XCTAssertTrue(
            registry.consume(
                capability,
                currentFingerprint: capability.contextFingerprint,
                currentProviderKey: capability.providerKey,
                now: now
            )
        )
        XCTAssertFalse(
            registry.consume(
                capability,
                currentFingerprint: capability.contextFingerprint,
                currentProviderKey: capability.providerKey,
                now: now
            )
        )

        let expired = AgentPageCapability(
            turnID: "turn-2",
            nonce: "nonce-2",
            contextFingerprint: "comic|chapter|1",
            providerKey: capability.providerKey
        )
        registry.issue(expired, expiresAt: now.addingTimeInterval(-1))
        XCTAssertFalse(
            registry.consume(
                expired,
                currentFingerprint: expired.contextFingerprint,
                currentProviderKey: expired.providerKey,
                now: now
            )
        )
    }

    func testOpenAIProtocolMessagesEncodeToolCallsResultsImagesAndParallelPolicy() throws {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let request = AgentTransportRequest(
            messages: [
                .assistant(.init(
                    text: nil,
                    toolCalls: [.init(id: "call-1", name: "currentContext", arguments: "{}")]
                )),
                .tool(callID: "call-1", content: "ok"),
                .transientImage(callID: "call-2", prompt: "page", jpegData: jpeg)
            ],
            tools: AgentToolCatalog().definitions
        )
        let encoded = try OpenAIAgentTransport.encodedRequest(model: "model", request: request)
        let text = String(decoding: encoded, as: UTF8.self)

        XCTAssertTrue(text.contains(#""tool_calls""#))
        XCTAssertTrue(text.contains(#""role":"tool""#))
        XCTAssertTrue(text.contains(#""tool_call_id":"call-1""#))
        XCTAssertTrue(text.contains(#""parallel_tool_calls":false"#))
        XCTAssertTrue(text.contains("data:image/jpeg;base64,"))
        XCTAssertFalse(text.contains("file://"))
    }

    func testOpenAIRejectsMultipleImagesBeforeNetwork() {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        XCTAssertThrowsError(try OpenAIAgentTransport.validateImages([
            .transientImage(callID: "one", prompt: "", jpegData: jpeg),
            .transientImage(callID: "two", prompt: "", jpegData: jpeg)
        ])) { error in
            XCTAssertEqual((error as? OpenAITransportError)?.code, .invalidImage)
        }
    }



    @MainActor
    func testImageBudgetAllowsOnlyThreeProviderImagesPerMinute() throws {
        let data = Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        )!
        AgentImageBudget.shared.resetForTesting()
        for index in 0..<3 {
            let capability = AgentPageCapability(
                turnID: "turn-\(index)",
                nonce: "nonce-\(index)",
                contextFingerprint: "comic|chapter|\(index)",
                providerKey: "openai|api.example.com|443"
            )
            XCTAssertNoThrow(try AgentImageBudget.shared.prepare(data, capability: capability))
        }
        let fourth = AgentPageCapability(
            turnID: "turn-3",
            nonce: "nonce-3",
            contextFingerprint: "comic|chapter|3",
            providerKey: "openai|api.example.com|443"
        )
        XCTAssertThrowsError(try AgentImageBudget.shared.prepare(data, capability: fourth)) { error in
            XCTAssertEqual(error as? AgentImageError, .rateLimited)
        }
        AgentImageBudget.shared.resetForTesting()
    }
 
    func testResultProjectorUsesCommandSpecificAllowlist() throws {
        let item = AgentSearchItem(try makeSummary())
        let search = AgentCommandResult.search([item])
        let projection = try XCTUnwrap(
            AgentResultProjector.project(search, for: .search(keyword: "comic", sort: .dd))
        )
        XCTAssertTrue(projection.contains("comicID=comic-1"))
        XCTAssertTrue(projection.contains("chapterCount=4"))
        XCTAssertFalse(projection.contains("thumb"))
        XCTAssertFalse(projection.contains("rawURL"))
        XCTAssertNil(
            AgentResultProjector.project(
                search,
                for: .currentUser
            )
        )
    }
    @MainActor
    func testProviderResultsAuthorizeReturnedComicIDsForOpen() async {
        let favorite = AgentFavoriteItem(
            comicID: "favorite-comic",
            title: "Favorite",
            author: "Author",
            chapterCount: 2,
            finished: false
        )
        let offline = AgentLibraryItem(
            comicID: "offline-comic",
            title: "Offline",
            chapterCount: 1,
            imageCount: 3,
            quality: .high,
            byteCount: 123,
            downloadedAt: Date()
        )
        let service = AgentCommandService(
            userProvider: StubAgentUserProvider(),
            libraryProvider: StubAgentLibraryProvider(favorites: [favorite], offline: [offline]),
            downloadProvider: StubAgentDownloadProvider(),
            sessionIsLoggedIn: { true }
        )

        _ = await service.execute(.favoritePage(page: 1, sort: .dd), sessionID: agentTestSessionID)
        let favoriteOpen = await service.execute(.openComic(comicID: favorite.comicID), sessionID: agentTestSessionID)
        XCTAssertEqual(favoriteOpen, .openedComic(comicID: favorite.comicID))

        _ = await service.execute(.offlineLibrary, sessionID: agentTestSessionID)
        let offlineOpen = await service.execute(.openComic(comicID: offline.comicID), sessionID: agentTestSessionID)
        XCTAssertEqual(offlineOpen, .openedComic(comicID: offline.comicID))

        let rawOpen = await service.execute(.openComic(comicID: "not-returned"), sessionID: agentTestSessionID)
        XCTAssertEqual(rawOpen, .failure(.invalidIdentifier))
    }
    @MainActor
    func testOfflineLibraryCapsItemsButPreservesSummary() async {
        let items = (0..<101).map { index in
            AgentLibraryItem(
                comicID: "offline-\(index)",
                title: "Offline \(index)",
                chapterCount: 1,
                imageCount: 2,
                quality: .high,
                byteCount: 10,
                downloadedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        let service = AgentCommandService(
            userProvider: StubAgentUserProvider(),
            libraryProvider: StubAgentLibraryProvider(favorites: [], offline: items, storageBytes: 1_010),
            downloadProvider: StubAgentDownloadProvider(),
            sessionIsLoggedIn: { true }
        )

        let result = await service.execute(.offlineLibrary, sessionID: agentTestSessionID)
        guard case let .offlineLibrary(cappedItems, totalCount, storageBytes) = result else {
            return XCTFail("Expected offline library result")
        }
        XCTAssertEqual(cappedItems.count, AgentOfflineLibrarySnapshot.defaultItemLimit)
        XCTAssertEqual(cappedItems.first?.comicID, "offline-0")
        XCTAssertEqual(totalCount, 101)
        XCTAssertEqual(storageBytes, 1_010)
    }
 
    @MainActor
    func testStartReadingRejectsUnknownChapterBeforeRouting() async {
        let favorite = AgentFavoriteItem(
            comicID: "comic-reading",
            title: "Reading",
            author: "Author",
            chapterCount: 2,
            finished: false
        )
        let chapter = PicaChapter(uid: "chapter-1", title: "Chapter 1", order: 1, id: "chapter-1")
        let navigation = AppNavigationCoordinator.shared
        navigation.resetForTesting()
        defer { navigation.resetForTesting() }
        let service = AgentCommandService(
            navigation: navigation,
            userProvider: StubAgentUserProvider(),
            libraryProvider: StubAgentLibraryProvider(favorites: [favorite], offline: []),
            downloadProvider: StubAgentDownloadProvider(),
            sessionIsLoggedIn: { true },
            chapterProvider: { _ in [chapter] }
        )
        _ = await service.execute(.favoritePage(page: 1, sort: .dd), sessionID: agentTestSessionID)

        let valid = await service.execute(.startReading(comicID: favorite.comicID, chapterID: chapter.id, pageIndex: 0), sessionID: agentTestSessionID)
        XCTAssertEqual(
            valid,
            .startedReading(comicID: favorite.comicID, chapterID: chapter.id, pageIndex: 0)
        )
        _ = navigation.consumePendingReaderRequest()

        let invalid = await service.execute(.startReading(comicID: favorite.comicID, chapterID: "chapter-unknown", pageIndex: 0), sessionID: agentTestSessionID)
        XCTAssertEqual(invalid, .failure(.invalidIdentifier))
        XCTAssertNil(navigation.pendingReaderRequest)
    }

    @MainActor
    func testReaderCommandsRejectNegativePagesWithoutRoutingOrMutation() async {
        let favorite = AgentFavoriteItem(
            comicID: "comic-pages",
            title: "Pages",
            author: "Author",
            chapterCount: 1,
            finished: false
        )
        let navigation = AppNavigationCoordinator.shared
        navigation.resetForTesting()
        defer { navigation.resetForTesting() }
        let service = AgentCommandService(
            navigation: navigation,
            userProvider: StubAgentUserProvider(),
            libraryProvider: StubAgentLibraryProvider(favorites: [favorite], offline: []),
            downloadProvider: StubAgentDownloadProvider(),
            sessionIsLoggedIn: { true },
            chapterProvider: { _ in [] }
        )
        _ = await service.execute(.favoritePage(page: 1, sort: .dd), sessionID: agentTestSessionID)

        let start = await service.execute(.startReading(comicID: favorite.comicID, chapterID: nil, pageIndex: -1), sessionID: agentTestSessionID)
        XCTAssertEqual(start, .failure(.invalidPage))
        XCTAssertNil(navigation.pendingReaderRequest)
    }
 
    @MainActor
    func testConfirmationPreviewContainsSanitizedActionDetails() async {
        let snapshot = AgentDownloadSnapshot(
            id: "job-1",
            comicID: "comic-1",
            title: "Comic",
            chapterIDs: ["chapter-1"],
            state: .downloading,
            completedImages: 2,
            totalImages: 10,
            errorMessage: nil
        )
        let favorite = AgentFavoriteItem(
            comicID: "comic-1",
            title: "Comic",
            author: "Author",
            chapterCount: 1,
            finished: false
        )
        let service = AgentCommandService(
            userProvider: StubAgentUserProvider(),
            libraryProvider: StubAgentLibraryProvider(favorites: [favorite], offline: []),
            downloadProvider: StubAgentDownloadProvider(snapshot: snapshot),
            sessionIsLoggedIn: { true }
        )
        _ = await service.execute(.favoritePage(page: 1, sort: .dd), sessionID: agentTestSessionID)

        let result = await service.execute(.cancelDownload(jobID: snapshot.id, commandID: "cancel-1"), sessionID: agentTestSessionID)
        guard case let .requiresConfirmation(.cancelDownload(jobID, title, completed, total, state)) = result else {
            return XCTFail("Expected structured cancellation preview")
        }
        XCTAssertEqual(jobID, "job-1")
        XCTAssertEqual(title, "Comic")
        XCTAssertEqual(completed, 2)
        XCTAssertEqual(total, 10)
        XCTAssertEqual(state, .downloading)
    }

    private func makeSummary() throws -> ComicSummary {
        let data = Data(
            """
            {
              "_id": "comic-1",
              "title": "Comic",
              "author": "Author",
              "thumb": { "fileServer": "https://images.example.com", "path": "image.jpg", "originalName": "image.jpg" },
              "epsCount": 4,
              "finished": true
            }
            """.utf8
        )
        return try JSONDecoder().decode(ComicSummary.self, from: data)
    }
}

private actor StubAgentUserProvider: AgentUserProvider {
    func currentUser() async throws -> AgentUserSnapshot {
        AgentUserSnapshot(displayName: "Test", level: 1, exp: 0, isPunched: false, favoriteCount: nil)
    }
}

private actor StubAgentLibraryProvider: AgentLibraryProvider {
    let favorites: [AgentFavoriteItem]
    let offline: [AgentLibraryItem]
    let storageBytes: Int

    init(favorites: [AgentFavoriteItem], offline: [AgentLibraryItem], storageBytes: Int? = nil) {
        self.favorites = favorites
        self.offline = offline
        self.storageBytes = storageBytes ?? offline.reduce(0) { $0 + $1.byteCount }
    }

    func favoritePage(page: Int, sort: ComicSortType) async throws -> [AgentFavoriteItem] {
        favorites
    }

    func offlineLibrary() async -> AgentOfflineLibrarySnapshot {
        AgentOfflineLibrarySnapshot(
            items: offline,
            totalCount: offline.count,
            storageBytes: storageBytes
        )
    }
}

private actor StubAgentDownloadProvider: AgentDownloadProvider {
    let snapshotValue: AgentDownloadSnapshot?

    init(snapshot: AgentDownloadSnapshot? = nil) {
        self.snapshotValue = snapshot
    }

    func activeDownloads() async -> [AgentDownloadSnapshot] {
        snapshotValue.map { [$0] } ?? []
    }

    func snapshot(jobID: String) async throws -> AgentDownloadSnapshot {
        guard let snapshotValue, snapshotValue.id == jobID else {
            throw AgentCommandError.invalidIdentifier
        }
        return snapshotValue
    }
}
