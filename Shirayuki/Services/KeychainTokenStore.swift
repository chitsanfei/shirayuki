import Foundation
import Security

enum KeychainTokenStore {
    private static let tokenAccount = "pica_token"
    private static let canonicalService = "shizukuworld.shirayuki"

    static func readToken() -> String? {
        readValue(account: tokenAccount)
    }

    static func saveToken(_ token: String) {
        saveValue(token, account: tokenAccount)
    }

    static func deleteToken() {
        deleteValue(account: tokenAccount)
    }

    static func readValue(account: String) -> String? {
        for service in serviceCandidates {
            if let value = readValue(account: account, service: service) {
                if service != canonicalService {
                    saveValue(value, account: account)
                }
                return value
            }
        }
        return nil
    }

    static func saveValue(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        let baseQuery = baseQuery(account: account, service: canonicalService)
        let attributes = baseQuery.merging([
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ]) { _, new in new }

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    static func deleteValue(account: String) {
        for service in serviceCandidates {
            SecItemDelete(baseQuery(account: account, service: service) as CFDictionary)
        }
    }

    private static func readValue(account: String, service: String) -> String? {
        var query = baseQuery(account: account, service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }

        return token
    }

    private static var serviceCandidates: [String] {
        var services: [String] = [canonicalService]
        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           !bundleIdentifier.isEmpty,
           !services.contains(bundleIdentifier) {
            services.append(bundleIdentifier)
        }
        return services
    }

    private static func baseQuery(account: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
