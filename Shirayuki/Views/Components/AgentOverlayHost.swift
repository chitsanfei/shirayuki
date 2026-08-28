import SwiftUI

/// Installs one Agent presenter over a visible surface while deduplicating nested hosts.
struct AgentOverlayHost<Content: View>: View {
    let context: AgentPageContext
    let isRoot: Bool
    let content: Content

    init(
        context: AgentPageContext,
        isRoot: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.context = context
        self.isRoot = isRoot
        self.content = content()
    }

    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @EnvironmentObject private var uiState: AgentUIState
    @State private var presenterID = UUID()
    @State private var contextRegistration: AgentContextRegistration?

    private var isReaderContext: Bool {
        if case .reader = context { return true }
        return false
    }
    var body: some View {
        content
            .overlay {
                if uiState.activePresenterID == presenterID, !uiState.isSuppressed {
                    ZStack {
                        AgentFloatingButton(avoidsReaderControls: isReaderContext)
                        if uiState.isConversationPresented {
                            AgentConversationView()
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .zIndex(1)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: uiState.isConversationPresented)
                }
            }
            .onAppear {
                uiState.acquirePresenter(presenterID)
                if isRoot {
                    navigation.setRootContext(context)
                } else if contextRegistration == nil {
                    contextRegistration = navigation.register(context)
                }
            }
            .onChange(of: context) { _, newContext in
                if isRoot {
                    navigation.setRootContext(newContext)
                } else if let contextRegistration {
                    navigation.update(contextRegistration, context: newContext)
                }
            }
            .onDisappear {
                uiState.releasePresenter(presenterID)
                if !isRoot, let contextRegistration {
                    navigation.unregister(contextRegistration)
                    self.contextRegistration = nil
                }
            }
    }
}

private struct AgentPageContextModifier: ViewModifier {
    let context: AgentPageContext
    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @State private var registration: AgentContextRegistration?
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard registration == nil else { return }
                registration = navigation.register(context)
            }
            .onChange(of: context) { _, newContext in
                if let registration {
                    navigation.update(registration, context: newContext)
                }
            }
            .onDisappear {
                if let registration {
                    navigation.unregister(registration)
                    self.registration = nil
                }
            }
    }
}

private struct AgentSettingsSuppressionModifier: ViewModifier {
    @EnvironmentObject private var uiState: AgentUIState
    @State private var isSuppressing = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !isSuppressing else { return }
                isSuppressing = true
                uiState.suppress()
            }
            .onDisappear {
                guard isSuppressing else { return }
                isSuppressing = false
                uiState.restore()
            }
    }
}

extension View {
    func agentSurfaceHost(context: AgentPageContext) -> some View {
        AgentOverlayHost(context: context) { self }
    }

    func agentPageContext(_ context: AgentPageContext) -> some View {
        modifier(AgentPageContextModifier(context: context))
    }

    func agentSettingsSuppressed() -> some View {
        modifier(AgentSettingsSuppressionModifier())
    }
}
