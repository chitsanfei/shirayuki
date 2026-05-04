import Foundation
import Combine
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isClearingCache = false
    @Published var cacheMessage: String?
    @Published var selectedEndpoint: APIEndpoint
    @Published var themeMode: AppThemeMode
    @Published var language: AppLanguage

    init() {
        selectedEndpoint = AppState.shared.apiEndpoint
        themeMode = AppThemeMode(rawValue: UserDefaults.standard.string(forKey: "app_theme_mode") ?? "") ?? .system
        language = AppLocalization.shared.language
    }
    
    func clearCache() {
        isClearingCache = true
        cacheMessage = nil
        Task {
            await ImageLoader.shared.clear()
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self.isClearingCache = false
                self.cacheMessage = AppLocalization.shared.text("settings.cache.cleared")
            }
        }
    }
    
    func setEndpoint(_ endpoint: APIEndpoint) {
        selectedEndpoint = endpoint
        AppState.shared.setAPIEndpoint(endpoint)
    }

    func setThemeMode(_ mode: AppThemeMode) {
        themeMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "app_theme_mode")
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        AppLocalization.shared.setLanguage(language)
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

    var licenseText: String {
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

    var thirdPartyNoticesText: String {
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
