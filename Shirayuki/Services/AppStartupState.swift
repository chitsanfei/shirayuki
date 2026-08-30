import Foundation

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
