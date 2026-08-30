import SwiftUI
import Combine

/// Shared UI state for Agent presentation, drag persistence, and Settings suppression.
@MainActor
final class AgentUIState: ObservableObject {
    static let shared = AgentUIState()

    @Published var isConversationPresented = false
    @Published private(set) var activePresenterID: UUID?
    @Published private(set) var isSuppressed = false

    private static let positionXKey = "agent_floating_button_x"
    private static let positionYKey = "agent_floating_button_y"
    private var presenterStack: [UUID] = []
    private var suppressionCount = 0

    private init() {}

    func acquirePresenter(_ id: UUID) {
        presenterStack.removeAll { $0 == id }
        presenterStack.append(id)
        activePresenterID = id
    }

    func releasePresenter(_ id: UUID) {
        presenterStack.removeAll { $0 == id }
        activePresenterID = presenterStack.last
    }

    func suppress() {
        suppressionCount += 1
        isSuppressed = true
        isConversationPresented = false
    }

    func restore() {
        suppressionCount = max(0, suppressionCount - 1)
        isSuppressed = suppressionCount > 0
    }

    func savedPosition(
        in bounds: CGRect,
        safeArea: EdgeInsets,
        buttonSize: CGFloat,
        reservedTop: CGFloat = 0,
        reservedBottom: CGFloat = 0
    ) -> CGPoint {
        let defaults = UserDefaults.standard
        let fallback = CGPoint(
            x: bounds.maxX - safeArea.trailing - buttonSize / 2 - 16,
            y: bounds.maxY - safeArea.bottom - buttonSize / 2 - 92
        )
        guard defaults.object(forKey: Self.positionXKey) != nil,
              defaults.object(forKey: Self.positionYKey) != nil else {
            return clamped(
                fallback,
                in: bounds,
                safeArea: safeArea,
                buttonSize: buttonSize,
                reservedTop: reservedTop,
                reservedBottom: reservedBottom
            )
        }
        return clamped(
            CGPoint(
                x: defaults.double(forKey: Self.positionXKey),
                y: defaults.double(forKey: Self.positionYKey)
            ),
            in: bounds,
            safeArea: safeArea,
            buttonSize: buttonSize,
            reservedTop: reservedTop,
            reservedBottom: reservedBottom
        )
    }

    func persist(
        _ position: CGPoint,
        in bounds: CGRect,
        safeArea: EdgeInsets,
        buttonSize: CGFloat,
        reservedTop: CGFloat = 0,
        reservedBottom: CGFloat = 0
    ) {
        let value = clamped(
            position,
            in: bounds,
            safeArea: safeArea,
            buttonSize: buttonSize,
            reservedTop: reservedTop,
            reservedBottom: reservedBottom
        )
        UserDefaults.standard.set(value.x, forKey: Self.positionXKey)
        UserDefaults.standard.set(value.y, forKey: Self.positionYKey)
    }
 
    func resetPosition(
        in bounds: CGRect,
        safeArea: EdgeInsets,
        buttonSize: CGFloat,
        reservedTop: CGFloat = 0,
        reservedBottom: CGFloat = 0
    ) -> CGPoint {
        UserDefaults.standard.removeObject(forKey: Self.positionXKey)
        UserDefaults.standard.removeObject(forKey: Self.positionYKey)
        return savedPosition(
            in: bounds,
            safeArea: safeArea,
            buttonSize: buttonSize,
            reservedTop: reservedTop,
            reservedBottom: reservedBottom
        )
    }

    func clamped(
        _ position: CGPoint,
        in bounds: CGRect,
        safeArea: EdgeInsets,
        buttonSize: CGFloat,
        reservedTop: CGFloat = 0,
        reservedBottom: CGFloat = 0
    ) -> CGPoint {
        let radius = buttonSize / 2
        let rawMinX = bounds.minX + safeArea.leading + radius + 8
        let rawMaxX = bounds.maxX - safeArea.trailing - radius - 8
        let rawMinY = bounds.minY + safeArea.top + radius + 8 + reservedTop
        let rawMaxY = bounds.maxY - safeArea.bottom - radius - 8 - reservedBottom
        let x = rawMinX <= rawMaxX
            ? min(max(position.x, rawMinX), rawMaxX)
            : bounds.midX
        let y = rawMinY <= rawMaxY
            ? min(max(position.y, rawMinY), rawMaxY)
            : bounds.midY
        return CGPoint(x: x, y: y)
    }
}
/// Draggable floating entry point for the Agent conversation panel.
struct AgentFloatingButton: View {
    let avoidsReaderControls: Bool
    @EnvironmentObject private var uiState: AgentUIState
    @EnvironmentObject private var appearance: AppAppearanceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isKeyboardFocused: Bool
    @AccessibilityFocusState private var isVoiceOverFocused: Bool
    @State private var position: CGPoint?
    @State private var dragOrigin: CGPoint?
    @State private var dragDistance: CGFloat = 0

    private let buttonSize: CGFloat = 56

    init(avoidsReaderControls: Bool = false) {
        self.avoidsReaderControls = avoidsReaderControls
    }

    private var reservedTop: CGFloat { avoidsReaderControls ? 64 : 0 }
    private var reservedBottom: CGFloat { avoidsReaderControls ? 190 : 0 }

    private var buttonLabel: some View {
        ZStack {
            if appearance.buttonStyle == .glass {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            } else {
                Circle()
                    .fill(Color.accentColor)
                    .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1))
                    .shadow(color: .black.opacity(0.24), radius: 14, x: 0, y: 7)
            }
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(appearance.buttonStyle == .glass ? Color.accentColor : .white)
        }
        .frame(width: buttonSize, height: buttonSize)
        .opacity(
            dragOrigin != nil || isKeyboardFocused || isVoiceOverFocused
                ? 1
                : appearance.buttonOpacity
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let bounds = geometry.frame(in: .local)
            let displayedPosition = uiState.clamped(
                position ?? uiState.savedPosition(
                    in: bounds,
                    safeArea: geometry.safeAreaInsets,
                    buttonSize: buttonSize,
                    reservedTop: reservedTop,
                    reservedBottom: reservedBottom
                ),
                in: bounds,
                safeArea: geometry.safeAreaInsets,
                buttonSize: buttonSize,
                reservedTop: reservedTop,
                reservedBottom: reservedBottom
            )

            Button {
                uiState.isConversationPresented = true
            } label: {
                buttonLabel
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .focused($isKeyboardFocused)
            .accessibilityFocused($isVoiceOverFocused)
            .accessibilityIdentifier("agentFloatingButton")
            .accessibilityLabel(AppLocalization.text("agent.button.open"))
            .accessibilityHint(AppLocalization.text("agent.accessibility.dragHint"))
            .accessibilityAdjustableAction { direction in
                let delta: CGFloat = direction == .increment ? 64 : -64
                let updated = uiState.clamped(
                    CGPoint(x: displayedPosition.x + delta, y: displayedPosition.y),
                    in: bounds,
                    safeArea: geometry.safeAreaInsets,
                    buttonSize: buttonSize,
                    reservedTop: reservedTop,
                    reservedBottom: reservedBottom
                )
                position = updated
                uiState.persist(
                    updated,
                    in: bounds,
                    safeArea: geometry.safeAreaInsets,
                    buttonSize: buttonSize,
                    reservedTop: reservedTop,
                    reservedBottom: reservedBottom
                )
            }
            .accessibilityAction(named: Text(AppLocalization.text("agent.accessibility.moveLeft"))) {
                let updated = uiState.clamped(
                    CGPoint(x: displayedPosition.x - 64, y: displayedPosition.y),
                    in: bounds,
                    safeArea: geometry.safeAreaInsets,
                    buttonSize: buttonSize,
                    reservedTop: reservedTop,
                    reservedBottom: reservedBottom
                )
                position = updated
                uiState.persist(updated, in: bounds, safeArea: geometry.safeAreaInsets, buttonSize: buttonSize, reservedTop: reservedTop, reservedBottom: reservedBottom)
            }
            .accessibilityAction(named: Text(AppLocalization.text("agent.accessibility.moveRight"))) {
                let updated = uiState.clamped(
                    CGPoint(x: displayedPosition.x + 64, y: displayedPosition.y),
                    in: bounds,
                    safeArea: geometry.safeAreaInsets,
                    buttonSize: buttonSize,
                    reservedTop: reservedTop,
                    reservedBottom: reservedBottom
                )
                position = updated
                uiState.persist(updated, in: bounds, safeArea: geometry.safeAreaInsets, buttonSize: buttonSize, reservedTop: reservedTop, reservedBottom: reservedBottom)
            }
            .accessibilityAction(named: Text(AppLocalization.text("agent.accessibility.moveUp"))) {
                let updated = uiState.clamped(
                    CGPoint(x: displayedPosition.x, y: displayedPosition.y - 64),
                    in: bounds,
                    safeArea: geometry.safeAreaInsets,
                    buttonSize: buttonSize,
                    reservedTop: reservedTop,
                    reservedBottom: reservedBottom
                )
                position = updated
                uiState.persist(updated, in: bounds, safeArea: geometry.safeAreaInsets, buttonSize: buttonSize, reservedTop: reservedTop, reservedBottom: reservedBottom)
            }
            .accessibilityAction(named: Text(AppLocalization.text("agent.accessibility.moveDown"))) {
                let updated = uiState.clamped(
                    CGPoint(x: displayedPosition.x, y: displayedPosition.y + 64),
                    in: bounds,
                    safeArea: geometry.safeAreaInsets,
                    buttonSize: buttonSize,
                    reservedTop: reservedTop,
                    reservedBottom: reservedBottom
                )
                position = updated
                uiState.persist(updated, in: bounds, safeArea: geometry.safeAreaInsets, buttonSize: buttonSize, reservedTop: reservedTop, reservedBottom: reservedBottom)
            }
            .accessibilityAction(named: Text(AppLocalization.text("agent.accessibility.resetPosition"))) {
                let updated = uiState.resetPosition(
                    in: bounds,
                    safeArea: geometry.safeAreaInsets,
                    buttonSize: buttonSize,
                    reservedTop: reservedTop,
                    reservedBottom: reservedBottom
                )
                position = updated
            }
            .position(displayedPosition)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if dragOrigin == nil {
                            dragOrigin = displayedPosition
                            dragDistance = 0
                        }
                        dragDistance = max(
                            dragDistance,
                            hypot(value.translation.width, value.translation.height)
                        )
                        guard let dragOrigin else { return }
                        position = uiState.clamped(
                            CGPoint(
                                x: dragOrigin.x + value.translation.width,
                                y: dragOrigin.y + value.translation.height
                            ),
                            in: bounds,
                            safeArea: geometry.safeAreaInsets,
                            buttonSize: buttonSize,
                            reservedTop: reservedTop,
                            reservedBottom: reservedBottom
                        )
                    }
                    .onEnded { _ in
                        defer {
                            dragOrigin = nil
                            dragDistance = 0
                        }
                        if dragDistance < 8 {
                            uiState.isConversationPresented = true
                            position = displayedPosition
                        } else if let position {
                            let clamped = uiState.clamped(
                                position,
                                in: bounds,
                                safeArea: geometry.safeAreaInsets,
                                buttonSize: buttonSize,
                                reservedTop: reservedTop,
                                reservedBottom: reservedBottom
                            )
                            if let animation = appearance.motionProfile(
                                systemReduceMotion: reduceMotion
                            ).buttonReleaseAnimation {
                                withAnimation(animation) { self.position = clamped }
                            } else {
                                self.position = clamped
                            }
                            uiState.persist(
                                clamped,
                                in: bounds,
                                safeArea: geometry.safeAreaInsets,
                                buttonSize: buttonSize,
                                reservedTop: reservedTop,
                                reservedBottom: reservedBottom
                            )
                        }
                    }
            )
            .onChange(of: geometry.size) { _, _ in
                position = uiState.savedPosition(
                    in: bounds,
                    safeArea: geometry.safeAreaInsets,
                    buttonSize: buttonSize,
                    reservedTop: reservedTop,
                    reservedBottom: reservedBottom
                )
            }
        }
        .allowsHitTesting(true)
    }
}
