import Foundation

enum SavedLoginCredentialStore {
    struct Credentials: Equatable {
        let username: String
        let password: String
    }

    private static let usernameKey = "saved_login_username"
    private static let rememberPasswordKey = "remember_login_password"
    private static let passwordAccount = "saved_login_password"

    static var savedUsername: String {
        UserDefaults.standard.string(forKey: usernameKey) ?? ""
    }

    static var shouldRememberPassword: Bool {
        UserDefaults.standard.object(forKey: rememberPasswordKey) as? Bool ?? false
    }

    static var rememberedCredentials: Credentials? {
        guard shouldRememberPassword else { return nil }
        let username = savedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = savedPassword()
        guard !username.isEmpty, !password.isEmpty else { return nil }
        return Credentials(username: username, password: password)
    }

    static var hasRememberedCredentials: Bool {
        rememberedCredentials != nil
    }

    static func savedPassword() -> String {
        guard shouldRememberPassword else { return "" }
        return KeychainTokenStore.readValue(account: passwordAccount) ?? ""
    }

    static func save(username: String, password: String, rememberPassword: Bool) {
        UserDefaults.standard.set(username, forKey: usernameKey)
        UserDefaults.standard.set(rememberPassword, forKey: rememberPasswordKey)
        if rememberPassword {
            KeychainTokenStore.saveValue(password, account: passwordAccount)
        } else {
            KeychainTokenStore.deleteValue(account: passwordAccount)
        }
    }

    static func clearSavedPassword() {
        UserDefaults.standard.set(false, forKey: rememberPasswordKey)
        KeychainTokenStore.deleteValue(account: passwordAccount)
    }
}
