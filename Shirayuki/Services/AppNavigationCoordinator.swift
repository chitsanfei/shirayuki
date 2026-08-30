import Foundation
import Combine

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

/// Opaque registration for one visible app surface.
nonisolated struct AgentContextRegistration: Hashable, Sendable {
    fileprivate let id: UUID
    fileprivate init(id: UUID = UUID()) {
        self.id = id
    }
}


/// Coordinates page context and pending comic/reader routes.
@MainActor
final class AppNavigationCoordinator: ObservableObject {
    static let shared = AppNavigationCoordinator()

    @Published private(set) var currentContext: AgentPageContext = .login
    @Published private(set) var pendingComicID: String?
    @Published private(set) var pendingReaderRequest: AgentReaderRequest?

    private struct RegisteredContext {
        let context: AgentPageContext
        let rootContext: AgentPageContext
        let sequence: UInt64
    }

    private var rootContext: AgentPageContext = .login
    private var contexts: [AgentContextRegistration: RegisteredContext] = [:]
    private var nextSequence: UInt64 = 0

    init() {}

    /// Makes the selected root tab authoritative over any retained offscreen tab views.
    func setSelectedTab(_ rawValue: String) {
        guard case .tab = rootContext else { return }
        rootContext = .tab(rawValue)
        recomputeContext()
    }

    /// Updates the visible root surface (startup, login, failed, or selected tab).
    func setRootContext(_ context: AgentPageContext) {
        rootContext = context
        recomputeContext()
    }
    @discardableResult
    func register(_ context: AgentPageContext) -> AgentContextRegistration {
        let registration = AgentContextRegistration()
        nextSequence &+= 1
        contexts[registration] = RegisteredContext(
            context: context,
            rootContext: rootContext,
            sequence: nextSequence
        )
        recomputeContext()
        return registration
    }

    func update(_ registration: AgentContextRegistration, context: AgentPageContext) {
        guard let current = contexts[registration] else { return }
        contexts[registration] = RegisteredContext(
            context: context,
            rootContext: current.rootContext,
            sequence: current.sequence
        )
        recomputeContext()
    }

    func unregister(_ registration: AgentContextRegistration) {
        contexts.removeValue(forKey: registration)
        recomputeContext()
    }

 
    func resetForTesting() {
        rootContext = .login
        contexts.removeAll()
        nextSequence = 0
        currentContext = rootContext
        pendingComicID = nil
        pendingReaderRequest = nil
    }

    func routeToComic(_ comicID: String) {
        let trimmed = comicID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingComicID = trimmed
    }

    func consumePendingComic() -> String? {
        defer { pendingComicID = nil }
        return pendingComicID
    }

    func routeToReader(comicID: String, chapterID: String? = nil, pageIndex: Int? = nil) {
        let trimmed = comicID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingReaderRequest = AgentReaderRequest(
            comicID: trimmed,
            chapterID: chapterID,
            pageIndex: pageIndex
        )
    }

    func consumePendingReaderRequest() -> AgentReaderRequest? {
        defer { pendingReaderRequest = nil }
        return pendingReaderRequest
    }

    private func recomputeContext() {
        let activeSurface = contexts.values
            .filter { registration in
                registration.rootContext == rootContext &&
                    !isTab(registration.context)
            }
            .max { lhs, rhs in lhs.sequence < rhs.sequence }
        currentContext = activeSurface?.context ?? rootContext
    }

    private func isTab(_ context: AgentPageContext) -> Bool {
        guard case .tab(let rawValue) = context else { return false }
        return AppTab(rawValue: rawValue) != nil
    }
}

nonisolated struct AgentReaderRequest: Equatable, Sendable {
    let comicID: String
    let chapterID: String?
    let pageIndex: Int?
}
