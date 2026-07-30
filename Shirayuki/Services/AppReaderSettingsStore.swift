import Foundation
import Combine

/// Persists and publishes reader behavior and presentation preferences.
@MainActor
final class AppReaderSettingsStore: ObservableObject {
    static let shared = AppReaderSettingsStore()

    private static let readModeKey = "reader_read_mode"
    private static let showPageNumbersKey = "reader_show_page_numbers"
    private static let menuLockedKey = "reader_menu_locked"
    private static let autoTurnIntervalKey = "reader_auto_turn_interval"
    private static let ignoreOfflineKey = "reader_ignore_offline"
    private static let downloadWhileReadingKey = "reader_download_while_reading"

    @Published private(set) var readMode: ReadMode
    @Published private(set) var showPageNumbers: Bool
    @Published private(set) var isMenuLocked: Bool
    @Published private(set) var autoTurnInterval: Double
    @Published private(set) var ignoresOfflineContent: Bool
    @Published private(set) var downloadsWhileReading: Bool

    private init() {
        readMode = ReadMode(
            rawValue: UserDefaults.standard.string(forKey: Self.readModeKey) ?? ""
        ) ?? .vertical
        showPageNumbers = UserDefaults.standard.object(forKey: Self.showPageNumbersKey) as? Bool ?? true
        isMenuLocked = UserDefaults.standard.object(forKey: Self.menuLockedKey) as? Bool ?? false

        let storedInterval = UserDefaults.standard.object(forKey: Self.autoTurnIntervalKey) as? Double ?? 5
        autoTurnInterval = Self.clampInterval(storedInterval)
        ignoresOfflineContent = UserDefaults.standard.object(forKey: Self.ignoreOfflineKey) as? Bool ?? false
        downloadsWhileReading = UserDefaults.standard.object(forKey: Self.downloadWhileReadingKey) as? Bool ?? false
    }

    func setReadMode(_ mode: ReadMode) {
        readMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.readModeKey)
    }

    func setShowPageNumbers(_ value: Bool) {
        showPageNumbers = value
        UserDefaults.standard.set(value, forKey: Self.showPageNumbersKey)
    }

    func setMenuLocked(_ value: Bool) {
        isMenuLocked = value
        UserDefaults.standard.set(value, forKey: Self.menuLockedKey)
    }

    func setAutoTurnInterval(_ value: Double) {
        let clamped = Self.clampInterval(value)
        autoTurnInterval = clamped
        UserDefaults.standard.set(clamped, forKey: Self.autoTurnIntervalKey)
    }

    func setIgnoresOfflineContent(_ value: Bool) {
        ignoresOfflineContent = value
        UserDefaults.standard.set(value, forKey: Self.ignoreOfflineKey)
    }

    func setDownloadsWhileReading(_ value: Bool) {
        downloadsWhileReading = value
        UserDefaults.standard.set(value, forKey: Self.downloadWhileReadingKey)
    }

    private static func clampInterval(_ value: Double) -> Double {
        min(max(value, 2), 60)
    }
}
