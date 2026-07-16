import Foundation
import Combine
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isClearingCache = false
    @Published var cacheMessage: String?
    @Published var imageCacheSize = 0
    @Published var offlineStorageSize = 0
    @Published var proxyName = ""
    @Published var proxyURL = ""
    @Published var editingProxyID: String?
    @Published var proxyMessage: String?
    @Published var themeMode: AppThemeMode
    @Published var language: AppLanguage
    @Published var imageQuality: AppImageQuality
    @Published var rankDisplay: RankMetadataDisplay
    @Published var rankMaxTagCount: Int

    init() {
        themeMode = AppThemeMode(rawValue: UserDefaults.standard.string(forKey: "app_theme_mode") ?? "") ?? .system
        language = AppLocalization.shared.language
        imageQuality = AppImageQuality.stored
        rankDisplay = AppRankDisplayStore.shared.display
        rankMaxTagCount = AppRankDisplayStore.shared.maxTagCount
        refreshStorageUsage()
    }
    
    func clearCache() {
        isClearingCache = true
        cacheMessage = nil
        Task {
            await ImageLoader.shared.clear()
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self.isClearingCache = false
                self.imageCacheSize = 0
                self.cacheMessage = AppLocalization.shared.text("settings.cache.cleared")
            }
        }
    }

    func refreshStorageUsage() {
        Task {
            async let cacheSize = ImageLoader.shared.cacheSize()
            async let offlineSize = OfflineComicStore.shared.storageSize()
            let (cache, offline) = await (cacheSize, offlineSize)
            imageCacheSize = cache
            offlineStorageSize = offline
        }
    }

    func clearOfflineStorage() {
        Task {
            try? await OfflineComicStore.shared.deleteAll()
            refreshStorageUsage()
        }
    }
    
    func selectProxyRule(_ rule: AppProxyRule) {
        AppProxyStore.shared.select(rule)
    }

    func beginEditingProxy(_ rule: AppProxyRule) {
        guard !rule.isBuiltIn else { return }
        editingProxyID = rule.id
        proxyName = rule.name
        proxyURL = rule.urlString
        proxyMessage = nil
    }

    @discardableResult
    func saveProxyRule() -> Bool {
        guard AppProxyStore.shared.saveUserRule(
            id: editingProxyID,
            name: proxyName,
            urlString: proxyURL
        ) else {
            proxyMessage = AppLocalization.text("settings.proxy.invalid")
            return false
        }
        proxyName = ""
        proxyURL = ""
        editingProxyID = nil
        proxyMessage = nil
        return true
    }

    func cancelEditingProxy() {
        proxyName = ""
        proxyURL = ""
        editingProxyID = nil
        proxyMessage = nil
    }

    func deleteProxyRule(_ rule: AppProxyRule) {
        AppProxyStore.shared.deleteUserRule(rule)
    }

    func setRankDisplay(_ display: RankMetadataDisplay) {
        rankDisplay = display
        AppRankDisplayStore.shared.setDisplay(display)
    }

    func setRankMaxTagCount(_ count: Int) {
        let clamped = min(max(count, 1), 5)
        rankMaxTagCount = clamped
        AppRankDisplayStore.shared.setMaxTagCount(clamped)
    }

    func setThemeMode(_ mode: AppThemeMode) {
        themeMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "app_theme_mode")
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        AppLocalization.shared.setLanguage(language)
    }

    func setImageQuality(_ quality: AppImageQuality) {
        AppImageQualityStore.shared.setImageQuality(quality)
        imageQuality = quality
    }
    
    var appVersion: String {
        "v\(AppMetadata.version)"
    }
    
    var sdkDisplay: String {
        if let sdk = Bundle.main.infoDictionary?["DTSDKName"] as? String, !sdk.isEmpty {
            return sdk
        }
        return "iPhoneOS"
    }

    var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "shizukuworld.shirayuki"
    }

    var repositoryURL: URL? {
        URL(string: "https://github.com/chitsanfei/shirayuki")
    }

    nonisolated static var licenseText: String {
        """
        GNU GENERAL PUBLIC LICENSE
        Version 3, 29 June 2007

        Shirayuki is distributed under GPL-3.0.

        You may use, study, modify, and redistribute this project under the terms of GPL-3.0.
        If you distribute modified versions, the corresponding source code and the same GPL license terms should remain available to recipients.

        Full license text:
        See the repository `LICENSE` file.

        Repository:
        https://github.com/chitsanfei/shirayuki
        """
    }

    nonisolated static var thirdPartyNoticesText: String {
        """
        Third-Party Notes

        1. haka_comic
        https://github.com/raoxwup/haka_comic
        Used as a design reference for interface and interaction.

        2. Apple Liquid Glass
        https://developer.apple.com/documentation/SwiftUI/Landmarks-Building-an-app-with-Liquid-Glass
        Used as a design reference for visuals and motion.

        Both references are for design guidance only.
        """
    }
}
