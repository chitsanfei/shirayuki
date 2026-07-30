import Foundation
import Combine

nonisolated struct AppProxyHostReplacement: Decodable, Equatable, Sendable {
    let from: String
    let to: String
}

nonisolated enum AppProxyRuleSource: String, Sendable {
    case official
    case bundled
    case user
}

nonisolated struct AppProxyRule: Equatable, Identifiable, Sendable {
    let id: String
    var name: String
    var urlString: String
    let source: AppProxyRuleSource
    let isEditable: Bool
    let imageHostReplacement: AppProxyHostReplacement?

    init(
        id: String,
        name: String,
        urlString: String,
        source: AppProxyRuleSource,
        isEditable: Bool,
        imageHostReplacement: AppProxyHostReplacement? = nil
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.source = source
        self.isEditable = isEditable
        self.imageHostReplacement = imageHostReplacement
    }

    var url: URL? {
        Self.validURL(from: urlString)
    }

    var displayName: String {
        isOfficial ? AppLocalization.text("endpoint.picacomic.name") : name
    }

    var isOfficial: Bool {
        source == .official
    }

    var canDelete: Bool {
        source == .user
    }

    func imageURL(for urlString: String) -> String {
        guard let replacement = imageHostReplacement,
              !replacement.from.isEmpty,
              !replacement.to.isEmpty,
              var components = URLComponents(string: urlString),
              let host = components.host,
              host.contains(replacement.from) else {
            return urlString
        }
        components.host = host.replacingOccurrences(of: replacement.from, with: replacement.to)
        return components.url?.absoluteString ?? urlString
    }

    static let official = AppProxyRule(
        id: "picacomic",
        name: "Picacomic",
        urlString: "https://picaapi.picacomic.com/",
        source: .official,
        isEditable: false
    )

    static func validURL(from rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            return nil
        }

        if !components.path.hasSuffix("/") {
            components.path += "/"
        }
        return components.url
    }

    static func decodeBundledRules(from data: Data) -> [AppProxyRule] {
        guard let definitions = try? JSONDecoder().decode([BundledRuleDefinition].self, from: data) else {
            return []
        }

        var ids = Set([official.id])
        return definitions.compactMap { definition -> AppProxyRule? in
            let id = definition.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = definition.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty,
                  !name.isEmpty,
                  ids.insert(id).inserted,
                  let url = validURL(from: definition.urlString) else {
                return nil
            }
            return AppProxyRule(
                id: id,
                name: name,
                urlString: url.absoluteString,
                source: .bundled,
                isEditable: definition.isEditable,
                imageHostReplacement: definition.imageHostReplacement
            )
        }
    }

    static func loadBundledRules() -> [AppProxyRule] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "NetworkRoutes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return decodeBundledRules(from: data)
    }
}

nonisolated private struct BundledRuleDefinition: Decodable {
    let id: String
    let name: String
    let urlString: String
    let isEditable: Bool
    let imageHostReplacement: AppProxyHostReplacement?
}

nonisolated private struct StoredProxyRule: Codable {
    let id: String
    let name: String
    let urlString: String
}

@MainActor
final class AppProxyStore: ObservableObject {
    static let shared = AppProxyStore()

    private static let rulesKey = "app_proxy_rules"
    private static let selectedRuleKey = "app_proxy_selected_rule"

    @Published private(set) var rules: [AppProxyRule]
    @Published private(set) var selectedRuleID: String

    var selectedRule: AppProxyRule {
        rules.first(where: { $0.id == selectedRuleID }) ?? .official
    }

    private init() {
        var allRules = [AppProxyRule.official] + AppProxyRule.loadBundledRules()
        for storedRule in Self.loadStoredRules() {
            guard let url = AppProxyRule.validURL(from: storedRule.urlString) else { continue }
            if let index = allRules.firstIndex(where: { $0.id == storedRule.id }) {
                guard allRules[index].isEditable else { continue }
                allRules[index].name = storedRule.name
                allRules[index].urlString = url.absoluteString
            } else {
                allRules.append(
                    AppProxyRule(
                        id: storedRule.id,
                        name: storedRule.name,
                        urlString: url.absoluteString,
                        source: .user,
                        isEditable: true
                    )
                )
            }
        }
        rules = allRules

        let storedSelection = UserDefaults.standard.string(forKey: Self.selectedRuleKey)
        selectedRuleID = allRules.contains(where: { $0.id == storedSelection })
            ? storedSelection!
            : AppProxyRule.official.id

        Task {
            await APIClient.shared.setBaseURL(selectedRule.urlString)
        }
    }

    func select(_ rule: AppProxyRule) {
        guard let storedRule = rules.first(where: { $0.id == rule.id }) else { return }
        selectedRuleID = storedRule.id
        UserDefaults.standard.set(storedRule.id, forKey: Self.selectedRuleKey)
        Task {
            await APIClient.shared.setBaseURL(storedRule.urlString)
        }
    }

    func saveUserRule(id: String?, name: String, urlString: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let normalizedURL = AppProxyRule.validURL(from: urlString) else {
            return false
        }

        if let id,
           let index = rules.firstIndex(where: { $0.id == id }) {
            guard rules[index].isEditable else { return false }
            rules[index].name = trimmedName
            rules[index].urlString = normalizedURL.absoluteString
            if selectedRuleID == id {
                select(rules[index])
            }
        } else {
            rules.append(
                AppProxyRule(
                    id: UUID().uuidString,
                    name: trimmedName,
                    urlString: normalizedURL.absoluteString,
                    source: .user,
                    isEditable: true
                )
            )
        }

        persistRules()
        return true
    }

    func deleteUserRule(_ rule: AppProxyRule) {
        guard rule.canDelete else { return }
        rules.removeAll { $0.id == rule.id }
        if selectedRuleID == rule.id {
            select(.official)
        }
        persistRules()
    }

    private static func loadStoredRules() -> [StoredProxyRule] {
        guard let data = UserDefaults.standard.data(forKey: rulesKey) else { return [] }
        return (try? JSONDecoder().decode([StoredProxyRule].self, from: data))?.filter {
            !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            AppProxyRule.validURL(from: $0.urlString) != nil
        } ?? []
    }

    private func persistRules() {
        let storedRules = rules
            .filter { $0.source == .user || ($0.source == .bundled && $0.isEditable) }
            .map { StoredProxyRule(id: $0.id, name: $0.name, urlString: $0.urlString) }
        guard let data = try? JSONEncoder().encode(storedRules) else { return }
        UserDefaults.standard.set(data, forKey: Self.rulesKey)
    }
}
