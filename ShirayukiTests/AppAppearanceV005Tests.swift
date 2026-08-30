import XCTest
@testable import Shirayuki

final class AppAppearanceV005Tests: XCTestCase {
    @MainActor
    func testDefaultsClampAndEffectiveMotionMatrix() async throws {
        let suite = "AppearanceV005.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppAppearanceStore(defaults: defaults)

        XCTAssertEqual(store.themeMode, .system)
        XCTAssertEqual(store.animationMode, .standard)
        XCTAssertEqual(store.buttonStyle, .glass)
        XCTAssertEqual(store.buttonOpacity, 1)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: false), .standard)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: true), .reduced)

        store.setAnimationMode(.reduced)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: false), .reduced)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: true), .reduced)
        store.setAnimationMode(.off)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: false), .off)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: true), .off)

        store.setButtonOpacity(0.41)
        XCTAssertEqual(store.buttonOpacity, 0.40)
        store.setButtonOpacity(1.4)
        XCTAssertEqual(store.buttonOpacity, 1.00)
    }
}
