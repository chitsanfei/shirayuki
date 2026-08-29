import SwiftUI
import Combine

/// User-selectable color-scheme policy for the application.
nonisolated enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { AppLocalization.text(titleKey) }

    private var titleKey: String {
        switch self {
        case .system: "theme.system"
        case .light: "theme.light"
        case .dark: "theme.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

nonisolated enum AppAnimationMode: String, CaseIterable, Identifiable, Sendable {
    case standard
    case reduced
    case off
    var id: String { rawValue }
}

nonisolated enum AgentFloatingButtonStyle: String, CaseIterable, Identifiable, Sendable {
    case accent
    case glass
    var id: String { rawValue }
}

nonisolated enum EffectiveMotionMode: Equatable, Sendable {
    case standard
    case reduced
    case off
}

nonisolated struct MotionProfile {
    let mode: EffectiveMotionMode

    var agentTransition: AnyTransition {
        switch mode {
        case .standard: .move(edge: .bottom).combined(with: .opacity)
        case .reduced: .opacity
        case .off: .identity
        }
    }

    var agentAnimation: Animation? {
        switch mode {
        case .standard: .spring(response: 0.34, dampingFraction: 0.86)
        case .reduced: .easeOut(duration: 0.12)
        case .off: nil
        }
    }

    var sessionTransition: AnyTransition {
        switch mode {
        case .standard: .move(edge: .bottom).combined(with: .opacity)
        case .reduced: .opacity
        case .off: .identity
        }
    }

    func gridAnimation(index: Int) -> Animation? {
        switch mode {
        case .standard:
            .spring(response: 0.38, dampingFraction: 0.84)
                .delay(min(Double(index % 8) * 0.035, 0.22))
        case .reduced: .easeOut(duration: 0.12)
        case .off: nil
        }
    }

    var readerToolbarAnimation: Animation? {
        switch mode {
        case .standard: .spring(response: 0.28, dampingFraction: 0.82)
        case .reduced: .easeOut(duration: 0.12)
        case .off: nil
        }
    }

    var toastTransition: AnyTransition {
        switch mode {
        case .standard: .opacity.combined(with: .scale(scale: 0.98))
        case .reduced: .opacity
        case .off: .identity
        }
    }

    var toastAnimation: Animation? {
        switch mode {
        case .standard: .easeOut(duration: 0.22)
        case .reduced: .easeOut(duration: 0.12)
        case .off: nil
        }
    }

    var buttonReleaseAnimation: Animation? {
        switch mode {
        case .standard: .spring(response: 0.28, dampingFraction: 0.84)
        case .reduced, .off: nil
        }
    }
}

@MainActor
final class AppAppearanceStore: ObservableObject {
    static let themeKey = "app_theme_mode"
    static let animationKey = "app_animation_mode"
    static let buttonStyleKey = "agent_floating_button_style"
    static let buttonOpacityKey = "agent_floating_button_opacity"

    @Published private(set) var themeMode: AppThemeMode
    @Published private(set) var animationMode: AppAnimationMode
    @Published private(set) var buttonStyle: AgentFloatingButtonStyle
    @Published private(set) var buttonOpacity: Double

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        themeMode = AppThemeMode(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? .system
        animationMode = AppAnimationMode(rawValue: defaults.string(forKey: Self.animationKey) ?? "") ?? .standard
        buttonStyle = AgentFloatingButtonStyle(rawValue: defaults.string(forKey: Self.buttonStyleKey) ?? "") ?? .glass
        let storedOpacity = defaults.object(forKey: Self.buttonOpacityKey) as? NSNumber
        buttonOpacity = Self.clampedOpacity(storedOpacity?.doubleValue ?? 1)
    }

    func setThemeMode(_ mode: AppThemeMode) {
        themeMode = mode
        defaults.set(mode.rawValue, forKey: Self.themeKey)
    }

    func setAnimationMode(_ mode: AppAnimationMode) {
        animationMode = mode
        defaults.set(mode.rawValue, forKey: Self.animationKey)
    }

    func setButtonStyle(_ style: AgentFloatingButtonStyle) {
        buttonStyle = style
        defaults.set(style.rawValue, forKey: Self.buttonStyleKey)
    }

    func setButtonOpacity(_ opacity: Double) {
        buttonOpacity = Self.clampedOpacity(opacity)
        defaults.set(buttonOpacity, forKey: Self.buttonOpacityKey)
    }

    func effectiveMode(systemReduceMotion: Bool) -> EffectiveMotionMode {
        switch animationMode {
        case .off: .off
        case .reduced: .reduced
        case .standard: systemReduceMotion ? .reduced : .standard
        }
    }

    func motionProfile(systemReduceMotion: Bool) -> MotionProfile {
        MotionProfile(mode: effectiveMode(systemReduceMotion: systemReduceMotion))
    }

    nonisolated static func clampedOpacity(_ value: Double) -> Double {
        let clamped = min(max(value, 0.40), 1.00)
        return (clamped / 0.05).rounded() * 0.05
    }
}
