import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Codex-style conversation surface backed by the persistent AgentRuntime.
struct AgentConversationView: View {
    @EnvironmentObject private var runtime: AgentRuntime
    @EnvironmentObject private var uiState: AgentUIState
    @ObservedObject private var localization = AppLocalization.shared
    @State private var showsHistory = false

    var body: some View {
        GeometryReader { geometry in
            let topInset = max(geometry.safeAreaInsets.top, 10)
            let bottomInset = max(geometry.safeAreaInsets.bottom, 8)
            let panelWidth = min(max(geometry.size.width - 20, 320), 680)
            let panelHeight = max(
                min(geometry.size.height - topInset - bottomInset, 760),
                360
            )
            VStack(spacing: 0) {
                header
                Divider()
                messages
                if let suspension = runtime.pendingConfirmation {
                    confirmation(suspension)
                }
                composer
            }
            .frame(width: panelWidth, height: panelHeight)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.20), radius: 30, x: 0, y: 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 10)
            .padding(.top, topInset)
            .padding(.bottom, bottomInset)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("agentConversationPanel")
        }
        .sheet(isPresented: $showsHistory) {
            NavigationStack { AgentSessionHistoryView() }
        }
        .alert(
            localization.text("settings.agent.history.cancelActive"),
            isPresented: Binding(
                get: { runtime.pendingHistoryAction != nil },
                set: { if !$0 { runtime.cancelHistoryAction() } }
            )
        ) {
            Button(localization.text("common.cancel"), role: .cancel) {
                runtime.cancelHistoryAction()
            }
            Button(localization.text("common.continue"), role: .destructive) {
                runtime.confirmHistoryAction()
            }
        }
    }


    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12))
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 38, height: 38)

            Text(localization.text("agent.title"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            toolbarButton(
                systemImage: "square.and.pencil",
                label: localization.text("settings.agent.history.new")
            ) {
                runtime.requestNewSession()
            }
            .disabled(runtime.isSideEffectExecuting)

            toolbarButton(
                systemImage: "clock.arrow.circlepath",
                label: localization.text("settings.agent.history")
            ) {
                showsHistory = true
            }

            toolbarButton(
                systemImage: "xmark",
                label: localization.text("common.close")
            ) {
                uiState.isConversationPresented = false
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
    }

    private func toolbarButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Color.secondary.opacity(0.10), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if runtime.activeSession?.messages.isEmpty ?? true {
                        emptyConversation
                    }

                    ForEach(
                        Array((runtime.activeSession?.messages ?? []).enumerated()),
                        id: \.offset
                    ) { index, record in
                        message(record)
                            .id(index)
                    }

                    if runtime.isLoading {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(localization.text("agent.loading"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 44)
                    }

                    if let stateCode = runtime.stateCode {
                        Label(
                            localization.text("agent.state.\(stateCode)"),
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.leading, 44)
                        .accessibilityIdentifier("agentState-\(stateCode)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: runtime.activeSession?.messages.count ?? 0) { _, count in
                guard count > 0 else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(count - 1, anchor: .bottom)
                }
            }
        }
    }

    private var emptyConversation: some View {
        VStack(spacing: 12) {
            Image(systemName: "ellipsis.message")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.secondary)
            Text(localization.text("agent.empty"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    @ViewBuilder
    private func message(_ record: AgentProtocolMessageRecord) -> some View {
        switch record {
        case let .user(_, text, _):
            HStack(alignment: .top) {
                Spacer(minLength: 52)
                Text(text)
                    .textSelection(.enabled)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 17))
            }

        case let .assistant(_, envelope, _):
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor.opacity(0.10), in: Circle())
                    if let text = envelope.text, !text.isEmpty {
                        markdownText(text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 5)
                    }
                }

                if !envelope.toolCalls.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(envelope.toolCalls, id: \.id) { call in
                            Label(call.name, systemImage: "wrench.and.screwdriver")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.08), in: Capsule())
                        }
                    }
                    .padding(.leading, 42)
                }
            }

        case let .tool(_, _, content, _):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                Text(content)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .padding(.leading, 42)
        }
    }

    @ViewBuilder
    private func markdownText(_ value: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: value,
            options: .init(interpretedSyntax: .full)
        ) {
            Text(attributed)
                .textSelection(.enabled)
                .font(.body)
                .foregroundStyle(.primary)
        } else {
            Text(value)
                .textSelection(.enabled)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    private func confirmation(_ suspension: AgentLoopSuspension) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(localization.text("agent.confirm.title"), systemImage: "checkmark.shield")
                .font(.headline)
            confirmationDetails(suspension.preview)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button(localization.text("common.cancel"), role: .cancel) {
                    runtime.rejectPending()
                }
                Spacer()
                Button(localization.text("common.confirm")) {
                    runtime.confirmPending()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.09))
        .overlay(alignment: .top) { Divider() }
        .accessibilityIdentifier("agentConfirmationCard")
    }

    @ViewBuilder
    private func confirmationDetails(_ preview: AgentConfirmationPreview) -> some View {
        switch preview {
        case let .download(_, title, chapters, quality, pages):
            Text("\(title) · \(chapters.count) · \(quality.displayName) · \(pages ?? 0)")
        case let .cancelDownload(_, title, completed, total, state):
            Text("\(title) · \(completed)/\(total) · \(state.rawValue)")
        case let .desiredState(_, title, action, desired):
            Text("\(title) · \(action.rawValue) · \(desired ? "true" : "false")")
        case let .currentPage(host):
            Text(localization.text("agent.confirm.currentPage.provider", host))
        case let .blockedWordAdd(display, normalized):
            Text("\(display) (\(normalized))")
        case let .blockedWordUpdate(oldDisplay, oldNormalized, newDisplay, newNormalized):
            Text("\(oldDisplay) (\(oldNormalized)) → \(newDisplay) (\(newNormalized))")
        case let .blockedWordRemove(display, normalized):
            Text("\(display) (\(normalized))")
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    localization.text("agent.input.placeholder"),
                    text: $runtime.input,
                    axis: .vertical
                )
                .lineLimit(1...5)
                .submitLabel(.send)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityIdentifier("agentInput")
                .onSubmit { runtime.send() }

                if runtime.isLoading {
                    Button(action: runtime.stop) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 42, height: 42)
                            .background(Color.secondary.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("agentStopButton")
                    .accessibilityLabel(localization.text("agent.stop"))
                } else {
                    Button(action: runtime.send) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                runtime.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.secondary.opacity(0.24)
                                    : Color.accentColor,
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(runtime.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("agentSendButton")
                    .accessibilityLabel(localization.text("agent.send"))
                }
            }
            .padding(12)
        }
        .background(Color.secondary.opacity(0.04))
    }
}
