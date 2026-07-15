import Foundation
import Combine

nonisolated struct AppProxyRule: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var name: String
    var urlString: String
    let isBuiltIn: Bool

    var url: URL? {
        Self.validURL(from: urlString)
    }

    static let go2778 = AppProxyRule(
        id: "go2778",
        name: "Go2778",
        urlString: "https://picaapi.go2778.com/",
        isBuiltIn: true
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
}

@MainActor
final class AppProxyStore: ObservableObject {
    static let shared = AppProxyStore()

    private static let rulesKey = "app_proxy_rules"
    private static let selectedRuleKey = "app_proxy_selected_rule"

    @Published private(set) var rules: [AppProxyRule]
    @Published private(set) var selectedRuleID: String

    var selectedRule: AppProxyRule {
        rules.first(where: { $0.id == selectedRuleID }) ?? .go2778
    }

    private init() {
        let storedRules = Self.loadRules()
        let allRules = [.go2778] + storedRules.filter { !$0.isBuiltIn && $0.id != AppProxyRule.go2778.id }
        rules = allRules

        let storedSelection = UserDefaults.standard.string(forKey: Self.selectedRuleKey)
        selectedRuleID = allRules.contains(where: { $0.id == storedSelection })
            ? storedSelection!
            : AppProxyRule.go2778.id

        Task {
            await APIClient.shared.setBaseURL(selectedRule.urlString)
        }
    }

    func select(_ rule: AppProxyRule) {
        guard rules.contains(where: { $0.id == rule.id }) else { return }
        selectedRuleID = rule.id
        UserDefaults.standard.set(rule.id, forKey: Self.selectedRuleKey)
        Task {
            await APIClient.shared.setBaseURL(rule.urlString)
        }
    }

    func saveUserRule(id: String?, name: String, urlString: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let normalizedURL = AppProxyRule.validURL(from: urlString) else {
            return false
        }

        if let id,
           let index = rules.firstIndex(where: { $0.id == id && !$0.isBuiltIn }) {
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
                    isBuiltIn: false
                )
            )
        }

        persistRules()
        return true
    }

    func deleteUserRule(_ rule: AppProxyRule) {
        guard !rule.isBuiltIn else { return }
        rules.removeAll { $0.id == rule.id }
        if selectedRuleID == rule.id {
            select(.go2778)
        }
        persistRules()
    }

    private static func loadRules() -> [AppProxyRule] {
        guard let data = UserDefaults.standard.data(forKey: rulesKey) else { return [] }
        return (try? JSONDecoder().decode([AppProxyRule].self, from: data))?.filter {
            !$0.isBuiltIn &&
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            AppProxyRule.validURL(from: $0.urlString) != nil
        } ?? []
    }

    private func persistRules() {
        guard let data = try? JSONEncoder().encode(rules.filter { !$0.isBuiltIn }) else { return }
        UserDefaults.standard.set(data, forKey: Self.rulesKey)
    }
}
