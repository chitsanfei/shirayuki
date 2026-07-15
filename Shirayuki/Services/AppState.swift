import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isLoggedIn = false
    @Published var token: String = ""
    @Published var isLoading = false
    @Published private(set) var isRestoringSession = false
    @Published var errorMessage: String?
    @Published var userProfile: UserProfileResponse?
    
    private var cancellables: Set<AnyCancellable> = []
    private var sessionRecoveryTask: Task<Void, Never>?
    private var isRecoveringSession = false
    
    private init() {
        // Token 只允许存放在 Keychain；UserDefaults 仅用于一次性向后兼容迁移。
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
            isInteractive: true
        )
    }
    
    func logout() {
        sessionRecoveryTask?.cancel()
        isRecoveringSession = false
        isRestoringSession = false
        token = ""
        isLoggedIn = false
        userProfile = nil
        errorMessage = nil
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
        await APIClient.shared.setBaseURL(AppProxyStore.shared.selectedRule.urlString)

        guard isRestoringSession else { return }
        defer { isRestoringSession = false }

        if !token.isEmpty {
            await APIClient.shared.setToken(token)
            do {
                userProfile = try await PicaAPIService.shared.fetchUserProfile()
                errorMessage = nil
                return
            } catch let error as APIError {
                if error != .unauthorized {
                    errorMessage = error.localizedDescription
                    return
                }
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        guard SavedLoginCredentialStore.hasRememberedCredentials else {
            if !token.isEmpty {
                logout()
            }
            return
        }

        let recovered = await recoverSessionFromSavedCredentials()
        if !recovered, !token.isEmpty {
            logout()
        }
    }

    private func recoverSessionAfterUnauthorized() {
        sessionRecoveryTask?.cancel()
        sessionRecoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let recovered = await self.recoverSessionFromSavedCredentials()
            if !recovered {
                self.logout()
            }
        }
    }

    @discardableResult
    private func recoverSessionFromSavedCredentials() async -> Bool {
        guard !isRecoveringSession else { return isLoggedIn }
        guard let credentials = SavedLoginCredentialStore.rememberedCredentials else { return false }

        isRecoveringSession = true
        defer { isRecoveringSession = false }

        do {
            try await performLogin(
                username: credentials.username,
                password: credentials.password,
                isInteractive: false
            )
            SavedLoginCredentialStore.save(
                username: credentials.username,
                password: credentials.password,
                rememberPassword: true
            )
            return true
        } catch {
            return false
        }
    }

    private func performLogin(
        username: String,
        password: String,
        isInteractive: Bool
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

            do {
                userProfile = try await PicaAPIService.shared.fetchUserProfile()
            } catch let error as APIError {
                if error == .unauthorized {
                    throw error
                }
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
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

enum APIEndpoint: String, CaseIterable, Identifiable {
    case picacomic = "https://picaapi.picacomic.com/"
    case go2778 = "https://picaapi.go2778.com/"
    
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .picacomic: return AppLocalization.text("endpoint.picacomic.name")
        case .go2778: return AppLocalization.text("endpoint.go2778.name")
        }
    }

    var description: String {
        switch self {
        case .picacomic:
            return AppLocalization.text("endpoint.picacomic.desc")
        case .go2778:
            return AppLocalization.text("endpoint.go2778.desc")
        }
    }
}
