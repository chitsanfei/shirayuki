import Combine
import Foundation

/// Wire formats supported by Agent transports.
nonisolated enum LLMProvider: String, CaseIterable, Identifiable, Sendable {
    case openAICompatible = "openai-compatible"
    case anthropicCompatible = "anthropic-compatible"

    var id: String { rawValue }
}

nonisolated enum AgentExecutionMode: String, CaseIterable, Identifiable, Sendable {
    case ask
    case yolo

    var id: String { rawValue }
}

/// Non-secret configuration used to create one provider request.
nonisolated struct LLMConfiguration: Equatable, Sendable {
    let provider: LLMProvider
    let model: String
    let baseURL: URL
    let requestURL: URL
    let keyAccount: String
}

nonisolated enum LLMSettingsApplyResult: Equatable, Sendable {
    case applied
    case invalid
    case privacyConfirmationRequired(host: String)
}

/// Persists LLM metadata in UserDefaults and API keys in provider-scoped Keychain accounts.
@MainActor
final class LLMSettingsStore: ObservableObject {
    static let shared = LLMSettingsStore()

    static let defaultProvider = LLMProvider.openAICompatible
    static let defaultModel = "deepseek-chat"
    nonisolated static let defaultAutoCompactEnabled = true
    nonisolated static let defaultAutoCompactThresholdKiB = 128
    nonisolated static let compactThresholdOptionsKiB = [64, 128, 256, 384]
    nonisolated static let defaultToolCallLimit = 10
    nonisolated static let maximumToolCallLimit = 20
    nonisolated static let defaultRiskAuthorizationEnabled = true
    private static let defaultEndpointString = "https://api.deepseek.com"

    private static let providerKey = "llm_provider"
    private static let modelKey = "llm_model"
    private static let baseURLKey = "llm_base_url"
    private static let executionModeKey = "agent_execution_mode"
    private static let autoCompactEnabledKey = "agent_auto_compact_enabled"
    private static let autoCompactThresholdKey = "agent_auto_compact_threshold_kib"
    private static let toolCallLimitKey = "agent_tool_call_limit"
    private static let riskAuthorizationKey = "agent_risk_authorization_enabled"
    private static let customEndpointConfirmedKey = "llm_custom_endpoint_confirmed"

    @Published private(set) var provider: LLMProvider
    @Published private(set) var model: String
    @Published private(set) var baseURLString: String
    @Published private(set) var customEndpointConfirmed: Bool
    @Published private(set) var executionMode: AgentExecutionMode
    @Published private(set) var autoCompactEnabled: Bool
    @Published private(set) var autoCompactThresholdKiB: Int
    @Published private(set) var toolCallLimit: Int
    @Published private(set) var riskAuthorizationEnabled: Bool

    private let defaults: UserDefaults
    private var volatileAPIKeys: [String: String] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedProvider = defaults.string(forKey: Self.providerKey)
        switch storedProvider {
        case LLMProvider.anthropicCompatible.rawValue:
            provider = .anthropicCompatible
        case LLMProvider.openAICompatible.rawValue, "openai":
            provider = .openAICompatible
        default:
            provider = Self.defaultProvider
        }
        executionMode = defaults.string(forKey: Self.executionModeKey)
            .flatMap(AgentExecutionMode.init(rawValue:)) ?? .ask
        autoCompactEnabled = defaults.object(forKey: Self.autoCompactEnabledKey) == nil
            ? Self.defaultAutoCompactEnabled
            : defaults.bool(forKey: Self.autoCompactEnabledKey)
        autoCompactThresholdKiB = Self.normalizedCompactThreshold(
            defaults.object(forKey: Self.autoCompactThresholdKey) as? Int
                ?? Self.defaultAutoCompactThresholdKiB
        )
        toolCallLimit = Self.normalizedToolCallLimit(
            defaults.object(forKey: Self.toolCallLimitKey) as? Int
                ?? Self.defaultToolCallLimit
        )
        riskAuthorizationEnabled = defaults.object(forKey: Self.riskAuthorizationKey) == nil
            ? Self.defaultRiskAuthorizationEnabled
            : defaults.bool(forKey: Self.riskAuthorizationKey)

        let storedModel = defaults.string(forKey: Self.modelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        model = storedModel.flatMap { $0.isEmpty ? nil : $0 } ?? Self.defaultModel

        let storedURL = defaults.string(forKey: Self.baseURLKey)
        let resolvedURL = Self.validEndpoint(storedURL)?.absoluteString
            ?? Self.defaultEndpoint.absoluteString
        baseURLString = resolvedURL
        customEndpointConfirmed = resolvedURL == Self.defaultEndpoint.absoluteString
            || defaults.bool(forKey: Self.customEndpointConfirmedKey)
    }

    static var defaultEndpoint: URL {
        URL(string: defaultEndpointString)!
    }

    /// Validates an HTTPS endpoint without credentials, query, or fragment.
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

    nonisolated static func requestEndpoint(provider: LLMProvider, baseURL: URL) -> URL {
        let path = baseURL.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        switch provider {
        case .openAICompatible:
            guard !path.hasSuffix("chat/completions"),
                  !path.hasSuffix("responses") else { return baseURL }
            return baseURL
                .appendingPathComponent("chat")
                .appendingPathComponent("completions")
        case .anthropicCompatible:
            guard !path.hasSuffix("messages") else { return baseURL }
            if path.isEmpty {
                return baseURL
                    .appendingPathComponent("v1")
                    .appendingPathComponent("messages")
            }
            return baseURL.appendingPathComponent("messages")
        }
    }

    nonisolated static func keyAccount(provider: LLMProvider, endpoint: URL) -> String {
        let host = endpoint.host?.lowercased() ?? "unknown"
        let port = endpoint.port ?? 443
        let hostPart = host.unicodeScalars.map { scalar in
            let value = scalar.value
            return scalar.isASCII && (
                value == 45 || value == 46 || value == 95
                    || value >= 48 && value <= 57
                    || value >= 65 && value <= 90
                    || value >= 97 && value <= 122
            ) ? String(scalar) : "_"
        }.joined()
        return "llm_\(provider.rawValue)_\(hostPart)_\(port)_api_key"
    }

    var endpoint: URL? { Self.validEndpoint(baseURLString) }

    var configuration: LLMConfiguration? {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let endpoint,
              endpoint == Self.defaultEndpoint || customEndpointConfirmed else {
            return nil
        }
        return LLMConfiguration(
            provider: provider,
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: endpoint,
            requestURL: Self.requestEndpoint(provider: provider, baseURL: endpoint),
            keyAccount: Self.keyAccount(provider: provider, endpoint: endpoint)
        )
    }

    var hasAPIKey: Bool {
        readAPIKey()?.isEmpty == false
    }

    var compactionPolicy: AgentContextCompactionPolicy {
        AgentContextCompactionPolicy(
            enabled: autoCompactEnabled,
            thresholdBytes: autoCompactThresholdKiB * 1024,
            preservedRecentTurns: 4
        )
    }


    func apply(
        provider: LLMProvider,
        model: String,
        baseURL: String,
        apiKey: String,
        executionMode: AgentExecutionMode = .ask,
        autoCompactEnabled: Bool = LLMSettingsStore.defaultAutoCompactEnabled,
        autoCompactThresholdKiB: Int = LLMSettingsStore.defaultAutoCompactThresholdKiB,
        toolCallLimit: Int = LLMSettingsStore.defaultToolCallLimit,
        riskAuthorizationEnabled: Bool = LLMSettingsStore.defaultRiskAuthorizationEnabled,
        privacyConfirmed: Bool = false
    ) -> LLMSettingsApplyResult {
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, let endpoint = Self.validEndpoint(baseURL) else { return .invalid }

        let sameConfirmedEndpoint = endpoint == self.endpoint && customEndpointConfirmed
        let isDefaultEndpoint = endpoint == Self.defaultEndpoint
        guard isDefaultEndpoint || sameConfirmedEndpoint || privacyConfirmed else {
            return .privacyConfirmationRequired(host: endpoint.host ?? endpoint.absoluteString)
        }

        self.provider = provider
        self.model = model
        self.baseURLString = endpoint.absoluteString
        self.customEndpointConfirmed = isDefaultEndpoint || sameConfirmedEndpoint || privacyConfirmed
        self.executionMode = executionMode
        self.autoCompactEnabled = autoCompactEnabled
        self.autoCompactThresholdKiB = Self.normalizedCompactThreshold(
            autoCompactThresholdKiB
        )
        self.toolCallLimit = Self.normalizedToolCallLimit(toolCallLimit)
        defaults.set(provider.rawValue, forKey: Self.providerKey)
        self.riskAuthorizationEnabled = riskAuthorizationEnabled
        defaults.set(model, forKey: Self.modelKey)
        defaults.set(baseURLString, forKey: Self.baseURLKey)
        defaults.set(customEndpointConfirmed, forKey: Self.customEndpointConfirmedKey)
        defaults.set(executionMode.rawValue, forKey: Self.executionModeKey)
        defaults.set(autoCompactEnabled, forKey: Self.autoCompactEnabledKey)
        defaults.set(self.autoCompactThresholdKiB, forKey: Self.autoCompactThresholdKey)
        defaults.set(self.toolCallLimit, forKey: Self.toolCallLimitKey)
        defaults.set(riskAuthorizationEnabled, forKey: Self.riskAuthorizationKey)

        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            let account = Self.keyAccount(provider: provider, endpoint: endpoint)
            volatileAPIKeys[account] = key
            KeychainTokenStore.saveValue(key, account: account)
        }
        objectWillChange.send()
        return .applied
    }

    @discardableResult
    func clearAPIKey() -> Bool {
        guard let endpoint else { return false }
        let account = Self.keyAccount(provider: provider, endpoint: endpoint)
        volatileAPIKeys[account] = nil
        KeychainTokenStore.deleteValue(account: account)
        objectWillChange.send()
        return KeychainTokenStore.readValue(account: account) == nil
    }
    func readAPIKey() -> String? {
        guard let configuration else { return nil }
        return volatileAPIKeys[configuration.keyAccount]
            ?? KeychainTokenStore.readValue(account: configuration.keyAccount)
    }

    func resetToDefaults() {
        provider = Self.defaultProvider
        model = Self.defaultModel
        baseURLString = Self.defaultEndpoint.absoluteString
        customEndpointConfirmed = true
        executionMode = .ask
        autoCompactEnabled = Self.defaultAutoCompactEnabled
        autoCompactThresholdKiB = Self.defaultAutoCompactThresholdKiB
        toolCallLimit = Self.defaultToolCallLimit
        riskAuthorizationEnabled = Self.defaultRiskAuthorizationEnabled
        defaults.set(provider.rawValue, forKey: Self.providerKey)
        defaults.set(model, forKey: Self.modelKey)
        defaults.set(baseURLString, forKey: Self.baseURLKey)
        defaults.set(true, forKey: Self.customEndpointConfirmedKey)
        defaults.set(executionMode.rawValue, forKey: Self.executionModeKey)
        defaults.set(autoCompactEnabled, forKey: Self.autoCompactEnabledKey)
        defaults.set(autoCompactThresholdKiB, forKey: Self.autoCompactThresholdKey)
        defaults.set(toolCallLimit, forKey: Self.toolCallLimitKey)
        defaults.set(riskAuthorizationEnabled, forKey: Self.riskAuthorizationKey)
    }


    nonisolated private static func normalizedToolCallLimit(_ value: Int) -> Int {
        min(max(value, 1), maximumToolCallLimit)
    }
    private static func normalizedCompactThreshold(_ value: Int) -> Int {
        compactThresholdOptionsKiB.min {
            abs($0 - value) < abs($1 - value)
        } ?? defaultAutoCompactThresholdKiB
    }
}
