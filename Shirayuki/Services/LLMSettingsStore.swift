import Foundation
import Combine

/// LLM transports supported by the internal Agent client.
nonisolated enum LLMProvider: String, CaseIterable, Identifiable, Sendable {
    case openAI = "openai"
    case openAICompatible = "openai-compatible"

    var id: String { rawValue }
}

/// Non-secret configuration used to create one provider request.
nonisolated struct LLMConfiguration: Equatable, Sendable {
    let provider: LLMProvider
    let model: String
    let baseURL: URL
    let keyAccount: String
}

/// Persists LLM metadata in UserDefaults and API keys in a provider-scoped Keychain account.
@MainActor
final class LLMSettingsStore: ObservableObject {
    static let shared = LLMSettingsStore()

    private static let providerKey = "llm_provider"
    private static let modelKey = "llm_model"
    private static let baseURLKey = "llm_base_url"
    private static let customEndpointConfirmedKey = "llm_custom_endpoint_confirmed"
    private static let officialEndpoint = "https://api.openai.com/v1/chat/completions"

    @Published private(set) var provider: LLMProvider
    @Published private(set) var model: String
    @Published private(set) var baseURLString: String
    @Published private(set) var customEndpointConfirmed: Bool

    private init(defaults: UserDefaults = .standard) {
        let storedProvider = defaults.string(forKey: Self.providerKey)
            .flatMap(LLMProvider.init(rawValue:))
        provider = storedProvider ?? .openAI
        model = defaults.string(forKey: Self.modelKey) ?? ""
        baseURLString = defaults.string(forKey: Self.baseURLKey) ?? Self.officialEndpoint
        customEndpointConfirmed = defaults.bool(forKey: Self.customEndpointConfirmedKey)
    }

    static var defaultEndpoint: URL {
        URL(string: officialEndpoint)!
    }

    /// Validates an HTTPS endpoint without accepting credentials, query, or fragments.
    nonisolated static func validEndpoint(_ rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              let host = url.host,
              !host.isEmpty,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil else {
            return nil
        }
        return url
    }

    /// Produces a stable provider/host/port-scoped Keychain account identifier.
    nonisolated static func keyAccount(provider: LLMProvider, endpoint: URL) -> String {
        let host = endpoint.host?.lowercased() ?? "unknown"
        let port = endpoint.port ?? 443
        let hostPart = host.unicodeScalars.map { scalar in
            let value = scalar.value
            return scalar.isASCII && (value == 45 || value == 46 || value == 95 || value >= 48 && value <= 57 || value >= 65 && value <= 90 || value >= 97 && value <= 122)
                ? String(scalar)
                : "_"
        }.joined()
        return "llm_\(provider.rawValue)_\(hostPart)_\(port)_api_key"
    }

    var endpoint: URL? {
        Self.validEndpoint(baseURLString)
    }

    var configuration: LLMConfiguration? {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let endpoint,
              provider == .openAI || customEndpointConfirmed else {
            return nil
        }
        return LLMConfiguration(
            provider: provider,
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: endpoint,
            keyAccount: Self.keyAccount(provider: provider, endpoint: endpoint)
        )
    }

    var hasAPIKey: Bool {
        guard let endpoint else { return false }
        return KeychainTokenStore.readValue(account: Self.keyAccount(provider: provider, endpoint: endpoint)) != nil
    }
    var apiKeyLastFour: String? {
        guard let endpoint,
              let key = KeychainTokenStore.readValue(account: Self.keyAccount(provider: provider, endpoint: endpoint)),
              !key.isEmpty else { return nil }
        guard key.count > 4 else { return key }
        return String(key.suffix(4))
    }

    func setProvider(_ provider: LLMProvider) {
        self.provider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: Self.providerKey)
        if provider == .openAI {
            baseURLString = Self.officialEndpoint
            customEndpointConfirmed = true
            UserDefaults.standard.set(baseURLString, forKey: Self.baseURLKey)
            UserDefaults.standard.set(true, forKey: Self.customEndpointConfirmedKey)
        } else {
            customEndpointConfirmed = false
            UserDefaults.standard.set(false, forKey: Self.customEndpointConfirmedKey)
        }
    }

    /// Stores a non-empty model; empty input is rejected so requests cannot use a fake default.
    @discardableResult
    func setModel(_ model: String) -> Bool {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        self.model = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.modelKey)
        return true
    }

    /// Sets an endpoint after HTTPS validation and, for custom hosts, explicit privacy confirmation.
    @discardableResult
    func setBaseURL(_ rawValue: String, privacyConfirmed: Bool = false) -> Bool {
        guard let url = Self.validEndpoint(rawValue) else { return false }
        let isOfficial = url.absoluteString == Self.officialEndpoint
        guard isOfficial || privacyConfirmed else { return false }
        baseURLString = url.absoluteString
        customEndpointConfirmed = isOfficial || privacyConfirmed
        UserDefaults.standard.set(baseURLString, forKey: Self.baseURLKey)
        UserDefaults.standard.set(customEndpointConfirmed, forKey: Self.customEndpointConfirmedKey)
        return true
    }

    @discardableResult
    func saveAPIKey(_ key: String) -> Bool {
        guard let configuration,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        KeychainTokenStore.saveValue(key, account: configuration.keyAccount)
        objectWillChange.send()
        return true
    }

    func clearAPIKey() {
        guard let endpoint else { return }
        KeychainTokenStore.deleteValue(account: Self.keyAccount(provider: provider, endpoint: endpoint))
        objectWillChange.send()
    }

    /// Returns the secret only to the isolated OpenAI client after full configuration validation.
    func readAPIKey() -> String? {
        guard let configuration else { return nil }
        return KeychainTokenStore.readValue(account: configuration.keyAccount)
    }

    func resetToOfficialEndpoint() {
        provider = .openAI
        model = ""
        baseURLString = Self.officialEndpoint
        customEndpointConfirmed = true
        UserDefaults.standard.set(provider.rawValue, forKey: Self.providerKey)
        UserDefaults.standard.set(model, forKey: Self.modelKey)
        UserDefaults.standard.set(baseURLString, forKey: Self.baseURLKey)
        UserDefaults.standard.set(true, forKey: Self.customEndpointConfirmedKey)
    }
}
