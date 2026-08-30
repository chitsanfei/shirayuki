import Foundation
import Combine
import SwiftUI

/// Owns authentication, session restoration, and the current user profile.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isLoggedIn = false
    private var token: String = ""
    @Published var isLoading = false
    @Published private(set) var isRestoringSession = false
    @Published private(set) var startupState: StartupState = .loading(.preparing)
    @Published var errorMessage: String?
    @Published var userProfile: UserProfileResponse?
    
    private var cancellables: Set<AnyCancellable> = []
    private var sessionRecoveryTask: Task<Void, Never>?
    private var isRecoveringSession = false
    private enum SessionRecoveryOutcome {
        case success
        case invalidCredentials
        case failed(String)
    }
    
    private init() {
        // Authentication tokens live only in Keychain. UserDefaults is read
        // once to migrate installations created by older app versions.
        let keychainToken = KeychainTokenStore.readToken()
        let legacyToken = UserDefaults.standard.string(forKey: "pica_token")
        if let keychainToken {
            self.token = keychainToken
        } else if let legacyToken, !legacyToken.isEmpty {
            KeychainTokenStore.saveToken(legacyToken)
            self.token = legacyToken
            UserDefaults.standard.removeObject(forKey: "pica_token")
        } else {
            self.token = ""
        }
        self.isLoggedIn = !token.isEmpty
        isRestoringSession = !token.isEmpty || SavedLoginCredentialStore.hasRememberedCredentials
        NotificationCenter.default.publisher(for: .apiClientDidReceiveUnauthorized)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recoverSessionAfterUnauthorized()
            }
            .store(in: &cancellables)
        Task {
            await restoreSessionIfNeeded()
        }
    }
    
    func login(username: String, password: String) async throws {
        try await performLogin(
            username: username,
            password: password,
            isInteractive: true,
            isStartup: false
        )
    }
    /// Re-runs startup restoration after a recoverable failure.
    func retryStartup() {
        sessionRecoveryTask?.cancel()
        isRestoringSession = !token.isEmpty || SavedLoginCredentialStore.hasRememberedCredentials
        Task {
            await restoreSessionIfNeeded()
        }
    }
    
    func logout() {
        sessionRecoveryTask?.cancel()
        isRecoveringSession = false
        isRestoringSession = false
        token = ""
        isLoggedIn = false
        userProfile = nil
        errorMessage = nil
        startupState = .readyUnauthenticated
        KeychainTokenStore.deleteToken()
        Task {
            await APIClient.shared.clearToken()
        }
    }
    
    func loadUserProfile() async {
        do {
            userProfile = try await PicaAPIService.shared.fetchUserProfile()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func restoreSessionIfNeeded() async {
        startupState = .loading(.preparing)
        await APIClient.shared.setBaseURL(AppProxyStore.shared.selectedRule.urlString)
        startupState = .loading(.validatingSession)

        guard isRestoringSession else {
            startupState = .readyUnauthenticated
            return
        }
        defer { isRestoringSession = false }

        if !token.isEmpty {
            await APIClient.shared.setToken(token)
            startupState = .loading(.loadingProfile)
            do {
                userProfile = try await PicaAPIService.shared.fetchUserProfile()
                errorMessage = nil
                startupState = .readyAuthenticated
                return
            } catch let error as APIError {
                if error != .unauthorized {
                    errorMessage = Self.sanitizedStartupMessage(error)
                    startupState = .failed(message: errorMessage ?? "startup_failed")
                    return
                }
                token = ""
                isLoggedIn = false
                await APIClient.shared.clearToken()
                KeychainTokenStore.deleteToken()
            } catch {
                errorMessage = Self.sanitizedStartupMessage(error)
                startupState = .failed(message: errorMessage ?? "startup_failed")
                return
            }
        }

        guard SavedLoginCredentialStore.hasRememberedCredentials else {
            startupState = .readyUnauthenticated
            return
        }

        startupState = .loading(.restoringCredentials)
        switch await recoverSessionFromSavedCredentials(isStartup: true) {
        case .success:
            startupState = .readyAuthenticated
        case .invalidCredentials:
            SavedLoginCredentialStore.clearSavedPassword()
            logout()
        case let .failed(message):
            errorMessage = message
            startupState = .failed(message: message)
        }
    }

    private func recoverSessionAfterUnauthorized() {
        sessionRecoveryTask?.cancel()
        sessionRecoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.recoverSessionFromSavedCredentials()
            if case .success = outcome { return }
            self.logout()
        }
    }

    @discardableResult
    private func recoverSessionFromSavedCredentials(isStartup: Bool = false) async -> SessionRecoveryOutcome {
        guard !isRecoveringSession else { return isLoggedIn ? .success : .failed("session_recovery_in_progress") }
        guard let credentials = SavedLoginCredentialStore.rememberedCredentials else {
            return .invalidCredentials
        }

        isRecoveringSession = true
        defer { isRecoveringSession = false }

        do {
            if isStartup {
                startupState = .loading(.restoringCredentials)
            }
            try await performLogin(
                username: credentials.username,
                password: credentials.password,
                isInteractive: false,
                isStartup: isStartup
            )
            SavedLoginCredentialStore.save(
                username: credentials.username,
                password: credentials.password,
                rememberPassword: true
            )
            return .success
        } catch let error as APIError {
            if error == .unauthorized {
                return .invalidCredentials
            }
            return .failed(Self.sanitizedStartupMessage(error))
        } catch {
            return .failed(Self.sanitizedStartupMessage(error))
        }
    }

    private static func sanitizedStartupMessage(_ error: Error) -> String {
        guard let error = error as? APIError else { return "startup_failed" }
        switch error {
        case .networkError:
            return "network_error"
        case .serverError(let code, _):
            return "server_error_\(code)"
        case .invalidURL:
            return "invalid_url"
        case .invalidResponse:
            return "invalid_response"
        case .unauthorized:
            return "unauthorized"
        case .emptyData:
            return "empty_data"
        case .encodingError:
            return "encoding_error"
        case .decodingError:
            return "decoding_error"
        }
    }

    private func performLogin(
        username: String,
        password: String,
        isInteractive: Bool,
        isStartup: Bool
    ) async throws {
        if isInteractive {
            isLoading = true
        }
        errorMessage = nil
        defer {
            if isInteractive {
                isLoading = false
            }
        }

        do {
            let restoredToken = try await PicaAPIService.shared.login(username: username, password: password)
            token = restoredToken
            isLoggedIn = true
            KeychainTokenStore.saveToken(restoredToken)
            await APIClient.shared.setToken(restoredToken)
            if isStartup {
                startupState = .loading(.loadingProfile)
            }

            do {
                userProfile = try await PicaAPIService.shared.fetchUserProfile()
            } catch let error as APIError {
                if error == .unauthorized || isStartup {
                    throw error
                }
                errorMessage = error.localizedDescription
            } catch {
                if isStartup {
                    throw error
                }
                errorMessage = error.localizedDescription
            }
            if isInteractive {
                startupState = .readyAuthenticated
            }
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
