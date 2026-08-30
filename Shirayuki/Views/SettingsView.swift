import SwiftUI

/// Standard navigation row used by settings categories.
struct SettingsCategoryRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
        }
    }
}

/// Controls application theme, language, and image quality.
struct AppearanceSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var localization = AppLocalization.shared
    @EnvironmentObject private var appearance: AppAppearanceStore

    var body: some View {
        Form {
            Section(localization.text("settings.appearance")) {
                Picker(localization.text("settings.theme"), selection: themeBinding) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker(
                    localization.text("settings.appearance.animation"),
                    selection: animationBinding
                ) {
                    ForEach(AppAnimationMode.allCases) { mode in
                        Text(localization.text("settings.appearance.animation.\(mode.rawValue)"))
                            .tag(mode)
                    }
                }

                Picker(
                    localization.text("settings.appearance.agentButtonStyle"),
                    selection: buttonStyleBinding
                ) {
                    ForEach(AgentFloatingButtonStyle.allCases) { style in
                        Text(localization.text("settings.appearance.agentButtonStyle.\(style.rawValue)"))
                            .tag(style)
                    }
                }

                VStack(alignment: .leading) {
                    Text(
                        "\(localization.text("settings.appearance.agentButtonOpacity")) "
                        + "\(Int((appearance.buttonOpacity * 100).rounded()))%"
                    )
                    Slider(
                        value: Binding(
                            get: { appearance.buttonOpacity },
                            set: { appearance.setButtonOpacity($0) }
                        ),
                        in: 0.40...1.00,
                        step: 0.05
                    )
                    .accessibilityIdentifier("agentButtonOpacitySlider")
                }

                Picker(
                    localization.text("settings.language"),
                    selection: Binding(
                        get: { viewModel.language },
                        set: { viewModel.setLanguage($0) }
                    )
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }
        }
        .navigationTitle(localization.text("settings.appearance"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var themeBinding: Binding<AppThemeMode> {
        Binding(get: { appearance.themeMode }, set: { appearance.setThemeMode($0) })
    }

    private var animationBinding: Binding<AppAnimationMode> {
        Binding(get: { appearance.animationMode }, set: { appearance.setAnimationMode($0) })
    }

    private var buttonStyleBinding: Binding<AgentFloatingButtonStyle> {
        Binding(get: { appearance.buttonStyle }, set: { appearance.setButtonStyle($0) })
    }
}

struct BlockedWordsSettingsView: View {
    @EnvironmentObject private var repository: UserDefaultsBlockedWordRepository
    @ObservedObject private var localization = AppLocalization.shared
    @State private var editorPresented = false
    @State private var editorValue = ""
    @State private var addingIncludedWord = false
    @State private var dangerAction: ContentFilterDangerAction?
    @State private var message: String?

    var body: some View {
        Form {
            Section(localization.text("settings.contentFilter.operations")) {
                Button {
                    addingIncludedWord = false
                    editorValue = ""
                    editorPresented = true
                } label: {
                    Label(
                        localization.text("settings.contentFilter.addBlocked"),
                        systemImage: "nosign"
                    )
                }
                .accessibilityIdentifier("addBlockedWordButton")

                Button {
                    addingIncludedWord = true
                    editorValue = ""
                    editorPresented = true
                } label: {
                    Label(
                        localization.text("settings.contentFilter.addIncluded"),
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }
                .accessibilityIdentifier("addIncludedWordButton")
            }

            Section(localization.text("settings.contentFilter.library")) {
                LabeledContent(
                    localization.text("settings.contentFilter.blockedCount"),
                    value: "\(repository.currentSnapshot.rules.count)"
                )
                LabeledContent(
                    localization.text("settings.contentFilter.includedCount"),
                    value: "\(repository.currentSnapshot.includeRules.count)"
                )

                NavigationLink(localization.text("settings.contentFilter.viewBlocked")) {
                    ContentFilterWordLibraryView(kind: .blocked)
                }
                .accessibilityIdentifier("viewBlockedWordsButton")

                NavigationLink(localization.text("settings.contentFilter.viewIncluded")) {
                    ContentFilterWordLibraryView(kind: .included)
                }
                .accessibilityIdentifier("viewIncludedWordsButton")
            }

            Section(localization.text("settings.contentFilter.danger")) {
                Button(
                    localization.text("settings.contentFilter.deleteAllBlocked"),
                    role: .destructive
                ) {
                    dangerAction = .deleteBlocked
                }
                Button(
                    localization.text("settings.contentFilter.deleteAllIncluded"),
                    role: .destructive
                ) {
                    dangerAction = .deleteIncluded
                }
                Button(
                    localization.text("settings.contentFilter.reset"),
                    role: .destructive
                ) {
                    dangerAction = .reset
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(localization.text("settings.contentFilter"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(
            editorPresented
                ? localization.text(
                    addingIncludedWord
                        ? "settings.contentFilter.addIncluded"
                        : "settings.contentFilter.addBlocked"
                )
                : localization.text("settings.contentFilter.edit"),
            isPresented: $editorPresented
        ) {
            TextField(localization.text("settings.contentFilter.word"), text: $editorValue)
            Button(localization.text("common.cancel"), role: .cancel) {}
            Button(localization.text("common.apply")) {
                Task { await saveEditor() }
            }
            .accessibilityIdentifier("saveBlockedWordButton")
        }
        .alert(item: $dangerAction) { action in
            Alert(
                title: Text(localization.text("settings.contentFilter.danger")),
                message: Text(localization.text(action.confirmationKey)),
                primaryButton: .destructive(Text(localization.text("common.delete"))) {
                    Task { await execute(action) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func saveEditor() async {
        do {
            if addingIncludedWord {
                _ = try repository.addIncluded(display: editorValue)
            } else {
                _ = try await repository.add(display: editorValue)
            }
            editorPresented = false
            message = localization.text("settings.contentFilter.saved")
        } catch let error as BlockedWordValidationError {
            message = localization.text("settings.contentFilter.error.\(error.rawValue)")
        } catch {
            message = localization.text("settings.contentFilter.error")
        }
    }

    private func execute(_ action: ContentFilterDangerAction) async {
        do {
            switch action {
            case .deleteBlocked:
                _ = try repository.deleteAllBlocked()
            case .deleteIncluded:
                _ = try repository.deleteAllIncluded()
            case .reset:
                _ = try repository.resetFilters()
            }
            message = localization.text("settings.contentFilter.saved")
        } catch {
            message = localization.text("settings.contentFilter.error")
        }
    }
}

private enum ContentFilterDangerAction: String, Identifiable {
    case deleteBlocked
    case deleteIncluded
    case reset

    var id: String { rawValue }

    var confirmationKey: String {
        switch self {
        case .deleteBlocked:
            "settings.contentFilter.deleteAllBlocked.confirm"
        case .deleteIncluded:
            "settings.contentFilter.deleteAllIncluded.confirm"
        case .reset:
            "settings.contentFilter.reset.confirm"
        }
    }
}

private enum ContentFilterWordLibraryKind: String, Identifiable {
    case blocked
    case included

    var id: String { rawValue }
}

private struct ContentFilterWordLibraryView: View {
    let kind: ContentFilterWordLibraryKind
    @EnvironmentObject private var repository: UserDefaultsBlockedWordRepository
    @ObservedObject private var localization = AppLocalization.shared
    @State private var editorPresented = false
    @State private var editorValue = ""
    @State private var editingRule: BlockedWordRule?

    private var rules: [BlockedWordRule] {
        switch kind {
        case .blocked:
            repository.currentSnapshot.rules
        case .included:
            repository.currentSnapshot.includeRules
        }
    }

    var body: some View {
        List {
            ForEach(rules, id: \.normalizedKey) { rule in
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.displayValue)
                    Text(rule.normalizedKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if kind == .blocked {
                        Button {
                            editingRule = rule
                            editorValue = rule.displayValue
                            editorPresented = true
                        } label: {
                            Label(localization.text("settings.contentFilter.edit"), systemImage: "pencil")
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        remove(rule)
                    } label: {
                        Label(localization.text("common.delete"), systemImage: "trash")
                    }
                }
            }
        }
        .overlay {
            if rules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "books.vertical")
                        .font(.title2)
                    Text(
                        localization.text(
                            kind == .blocked
                                ? "settings.contentFilter.viewBlocked"
                                : "settings.contentFilter.viewIncluded"
                        )
                    )
                    .font(.footnote)
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(
            localization.text(
                kind == .blocked
                    ? "settings.contentFilter.viewBlocked"
                    : "settings.contentFilter.viewIncluded"
            )
        )
        .alert(
            localization.text("settings.contentFilter.edit"),
            isPresented: $editorPresented
        ) {
            TextField(localization.text("settings.contentFilter.word"), text: $editorValue)
            Button(localization.text("common.cancel"), role: .cancel) {}
            Button(localization.text("common.apply")) {
                Task { await saveEdit() }
            }
        }
    }

    private func saveEdit() async {
        guard let editingRule else { return }
        do {
            _ = try await repository.update(
                normalizedOld: editingRule.normalizedKey,
                newDisplay: editorValue
            )
            editorPresented = false
            self.editingRule = nil
        } catch {
            // Keep editor open so invalid input remains recoverable.
        }
    }

    private func remove(_ rule: BlockedWordRule) {
        Task {
            do {
                if kind == .blocked {
                    _ = try await repository.remove(normalizedKey: rule.normalizedKey)
                } else {
                    _ = try repository.removeIncluded(normalizedKey: rule.normalizedKey)
                }
            } catch {
                // Row is retained; repository remains source of truth.
            }
        }
    }
}

/// Controls metadata shown by ranking cards.
struct RankSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var localization = AppLocalization.shared

    var body: some View {
        Form {
            Section(localization.text("settings.rank.title")) {
                Picker(
                    localization.text("settings.rank.display"),
                    selection: Binding(
                        get: { viewModel.rankDisplay },
                        set: { viewModel.setRankDisplay($0) }
                    )
                ) {
                    ForEach(RankMetadataDisplay.allCases) { display in
                        Text(localization.text(display.localizationKey)).tag(display)
                    }
                }

                Stepper(
                    value: Binding(
                        get: { viewModel.rankMaxTagCount },
                        set: { viewModel.setRankMaxTagCount($0) }
                    ),
                    in: 1...5
                ) {
                    HStack {
                        Text(localization.text("settings.rank.maxCount"))
                        Spacer()
                        Text("\(viewModel.rankMaxTagCount)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle(localization.text("settings.rank.title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Controls reader behavior and presentation defaults.
struct ReadingSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var readerSettings = AppReaderSettingsStore.shared
    @ObservedObject private var localization = AppLocalization.shared

    var body: some View {
        Form {
            Section(localization.text("reader.settings.direction")) {
                Picker(
                    localization.text("reader.settings.direction.label"),
                    selection: Binding(
                        get: { readerSettings.readMode },
                        set: { readerSettings.setReadMode($0) }
                    )
                ) {
                    ForEach(ReadMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(localization.text("reader.settings.display")) {
                Toggle(
                    localization.text("reader.settings.showPageNumbers"),
                    isOn: Binding(
                        get: { readerSettings.showPageNumbers },
                        set: { readerSettings.setShowPageNumbers($0) }
                    )
                )
                Toggle(
                    localization.text("reader.settings.lockMenu"),
                    isOn: Binding(
                        get: { readerSettings.isMenuLocked },
                        set: { readerSettings.setMenuLocked($0) }
                    )
                )
            }

            Section(localization.text("reader.settings.imageQuality")) {
                Picker(
                    localization.text("reader.settings.imageQuality.label"),
                    selection: Binding(
                        get: { viewModel.imageQuality },
                        set: { viewModel.setImageQuality($0) }
                    )
                ) {
                    ForEach(AppImageQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
            }

            Section(localization.text("reader.settings.autoTurn")) {
                HStack {
                    Text(localization.text("reader.settings.autoTurn.interval"))
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { readerSettings.autoTurnInterval },
                            set: { readerSettings.setAutoTurnInterval($0) }
                        ),
                        in: 2...60,
                        step: 1
                    )
                    .frame(width: 170)
                    Text("\(Int(readerSettings.autoTurnInterval))s")
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Section(localization.text("reader.settings.offline")) {
                Toggle(
                    localization.text("reader.settings.ignoreOffline"),
                    isOn: Binding(
                        get: { readerSettings.ignoresOfflineContent },
                        set: { readerSettings.setIgnoresOfflineContent($0) }
                    )
                )
                Toggle(
                    localization.text("reader.settings.downloadWhileReading"),
                    isOn: Binding(
                        get: { readerSettings.downloadsWhileReading },
                        set: { readerSettings.setDownloadsWhileReading($0) }
                    )
                )
            }
        }
        .navigationTitle(localization.text("settings.reading"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Selects, creates, edits, and deletes API routes.
struct NetworkSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var proxyStore = AppProxyStore.shared
    @ObservedObject private var localization = AppLocalization.shared
    @State private var editor: ProxyEditorContext?

    var body: some View {
        Form {
            Section(localization.text("settings.network.selection")) {
                ForEach(proxyStore.rules) { rule in
                    HStack(spacing: 10) {
                        Button {
                            viewModel.selectProxyRule(rule)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: rule.isOfficial ? "checkmark.shield.fill" : "network")
                                    .foregroundStyle(rule.isOfficial ? .green : Color.accentColor)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(rule.displayName).foregroundStyle(.primary)
                                    Text(rule.urlString)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if proxyStore.selectedRuleID == rule.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        if rule.isEditable {
                            Button {
                                viewModel.beginEditingProxy(rule)
                                editor = ProxyEditorContext(rule: rule)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                        }

                        if rule.canDelete {
                            Button {
                                viewModel.deleteProxyRule(rule)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        } else if !rule.isEditable {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section(localization.text("settings.network.modify")) {
                Button {
                    viewModel.cancelEditingProxy()
                    editor = ProxyEditorContext(rule: nil)
                } label: {
                    Label(localization.text("settings.proxy.add"), systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle(localization.text("settings.network"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $editor) { context in
            ProxyEditorSheet(viewModel: viewModel, rule: context.rule)
        }
    }
}

private struct ProxyEditorContext: Identifiable {
    let id = UUID()
    let rule: AppProxyRule?
}

private struct ProxyEditorSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    let rule: AppProxyRule?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localization = AppLocalization.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        localization.text("settings.proxy.name"),
                        text: $viewModel.proxyName
                    )
                    TextField(
                        localization.text("settings.proxy.url"),
                        text: $viewModel.proxyURL
                    )
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                }

                if let message = viewModel.proxyMessage {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(
                localization.text(rule == nil ? "settings.proxy.add" : "settings.proxy.save")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.text("common.cancel")) {
                        viewModel.cancelEditingProxy()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text("common.done")) {
                        if viewModel.saveProxyRule() {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

private struct SettingsNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum StorageSettingsDestructiveAction: String {
    case clearOffline
    case deleteSessions
}

private enum StorageSettingsAlert: Identifiable {
    case destructive(StorageSettingsDestructiveAction)
    case notice(SettingsNotice)

    var id: String {
        switch self {
        case let .destructive(action): "destructive-\(action.rawValue)"
        case let .notice(notice): "notice-\(notice.id.uuidString)"
        }
    }
}

/// Reports and clears image-cache and offline storage.
struct StorageSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var localization = AppLocalization.shared
    @EnvironmentObject private var runtime: AgentRuntime
    @State private var activeAlert: StorageSettingsAlert?
    @State private var deletingOfflineStorage = false
    @State private var deletingSessions = false

    var body: some View {
        Form {
            Section(localization.text("settings.cache")) {
                StorageUsageBar(
                    cacheBytes: viewModel.imageCacheSize,
                    offlineBytes: viewModel.offlineStorageSize,
                    sessionBytes: runtime.sessionStorageBytes
                )
                .padding(.vertical, 8)

                Button {
                    viewModel.clearCache()
                } label: {
                    HStack {
                        Text(
                            viewModel.isClearingCache
                            ? localization.text("settings.cache.clearing")
                            : localization.text("settings.cache.clear")
                        )
                        Spacer()
                        if viewModel.isClearingCache { ProgressView() }
                    }
                }
                .disabled(viewModel.isClearingCache)

                NavigationLink(localization.text("settings.storage.offline.manage")) {
                    OfflineComicsView()
                }

                Button(role: .destructive) {
                    activeAlert = .destructive(.clearOffline)
                } label: {
                    HStack {
                        Text(localization.text("settings.storage.offline.clear"))
                        Spacer()
                        if deletingOfflineStorage { ProgressView() }
                    }
                }
                .disabled(deletingOfflineStorage)
                .accessibilityIdentifier("storageSettingsClearOfflineButton")

                Button(role: .destructive) {
                    activeAlert = .destructive(.deleteSessions)
                } label: {
                    HStack {
                        Text(localization.text("settings.storage.agent.deleteAll"))
                        Spacer()
                        if deletingSessions { ProgressView() }
                    }
                }
                .disabled(runtime.sessionStorageBytes == 0 || deletingSessions)
                .accessibilityIdentifier("storageSettingsDeleteAllSessionsButton")

                if let message = viewModel.cacheMessage {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(localization.text("settings.cache"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            viewModel.refreshStorageUsage()
            await runtime.refreshHistory()
        }
        .alert(
            activeAlert.map(alertTitle) ?? "",
            isPresented: alertIsPresented,
            presenting: activeAlert
        ) { alert in
            switch alert {
            case let .destructive(action):
                Button(localization.text("common.cancel"), role: .cancel) {}
                    .accessibilityIdentifier("storageSettingsAlertCancelButton")
                Button(localization.text("common.delete"), role: .destructive) {
                    perform(action)
                }
                .accessibilityIdentifier("storageSettingsConfirm-\(action.rawValue)")
            case .notice:
                Button(localization.text("common.confirm")) {}
                    .accessibilityIdentifier("storageSettingsNoticeDismissButton")
            }
        } message: {
            Text(alertMessage($0))
        }
    }

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { activeAlert != nil },
            set: { if !$0 { activeAlert = nil } }
        )
    }

    private func alertTitle(_ alert: StorageSettingsAlert) -> String {
        switch alert {
        case .destructive(.clearOffline):
            localization.text("settings.storage.offline.clear")
        case .destructive(.deleteSessions):
            localization.text("settings.storage.agent.deleteAll")
        case let .notice(notice):
            notice.title
        }
    }

    private func alertMessage(_ alert: StorageSettingsAlert) -> String {
        switch alert {
        case .destructive(.clearOffline):
            localization.text("settings.storage.offline.clear.confirm")
        case .destructive(.deleteSessions):
            localization.text("settings.storage.agent.deleteAll.confirm")
        case let .notice(notice):
            notice.message
        }
    }

    private func perform(_ action: StorageSettingsDestructiveAction) {
        switch action {
        case .clearOffline:
            deletingOfflineStorage = true
            Task {
                do {
                    try await viewModel.clearOfflineStorage()
                    presentNotice(
                        title: localization.text("settings.storage.offline.clear"),
                        message: localization.text("settings.storage.offline.clear.done")
                    )
                } catch {
                    presentNotice(
                        title: localization.text("settings.agent.action.error"),
                        message: localization.text("settings.storage.offline.clear.error")
                    )
                }
                deletingOfflineStorage = false
            }
        case .deleteSessions:
            deletingSessions = true
            Task {
                do {
                    try await runtime.deleteAll()
                    presentNotice(
                        title: localization.text("settings.storage.agent.deleteAll"),
                        message: localization.text("settings.storage.agent.deleteAll.done")
                    )
                } catch {
                    presentNotice(
                        title: localization.text("settings.agent.action.error"),
                        message: localization.text("settings.storage.agent.deleteAll.error")
                    )
                }
                deletingSessions = false
            }
        }
    }

    private func presentNotice(title: String, message: String) {
        Task { @MainActor in
            await Task.yield()
            activeAlert = .notice(SettingsNotice(title: title, message: message))
        }
    }
}

private struct StorageUsageBar: View {
    let cacheBytes: Int
    let offlineBytes: Int
    let sessionBytes: Int

    private var total: Int { max(cacheBytes + offlineBytes + sessionBytes, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(cacheBytes) / CGFloat(total))
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * CGFloat(offlineBytes) / CGFloat(total))
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geometry.size.width * CGFloat(sessionBytes) / CGFloat(total))
                    Spacer(minLength: 0)
                }
                .clipShape(Capsule())
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
            .frame(height: 12)

            HStack {
                StorageLegend(color: .accentColor, title: AppLocalization.text("settings.storage.cache"), bytes: cacheBytes)
                Spacer()
                StorageLegend(color: .orange, title: AppLocalization.text("settings.storage.offline"), bytes: offlineBytes)
                Spacer()
                StorageLegend(color: .purple, title: AppLocalization.text("settings.storage.agent"), bytes: sessionBytes)
            }
        }
    }
}

private struct StorageLegend: View {
    let color: Color
    let title: String
    let bytes: Int

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(title) \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

/// Displays source-code and design-reference information.
struct SourceSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var localization = AppLocalization.shared

    var body: some View {
        Form {
            Section(localization.text("settings.source")) {
                HStack {
                    Text(localization.text("settings.deviceCode"))
                    Spacer()
                    Text(viewModel.bundleIdentifier)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                if let repositoryURL = viewModel.repositoryURL {
                    Link(destination: repositoryURL) {
                        Label(
                            localization.text("settings.repository"),
                            systemImage: "chevron.left.forwardslash.chevron.right"
                        )
                    }
                }

                NavigationLink(localization.text("settings.license")) {
                    TextDocumentView(
                        title: localization.text("settings.license"),
                        text: SettingsViewModel.licenseText
                    )
                }

                NavigationLink(localization.text("settings.references")) {
                    TextDocumentView(
                        title: localization.text("settings.references"),
                        text: SettingsViewModel.thirdPartyNoticesText
                    )
                }
            }
        }
        .navigationTitle(localization.text("settings.source"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Displays version, license, and third-party notices.
struct AboutSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var localization = AppLocalization.shared

    var body: some View {
        Form {
            Section(localization.text("settings.about")) {
                HStack {
                    Text(localization.text("settings.version"))
                    Spacer()
                    Text(viewModel.appVersion)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(localization.text("settings.sdk"))
                    Spacer()
                    Text(viewModel.sdkDisplay)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(localization.text("settings.about"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private enum AgentSettingsDestructiveAction: String, Identifiable {
    case clearToken
    case reset
    case deleteSessions

    var id: String { rawValue }
}

private enum AgentSettingsAlert: Identifiable {
    case customHost(String)
    case destructive(AgentSettingsDestructiveAction)
    case notice(SettingsNotice)

    var id: String {
        switch self {
        case .customHost: "custom-host"
        case let .destructive(action): "destructive-\(action.rawValue)"
        case let .notice(notice): "notice-\(notice.id.uuidString)"
        }
    }
}

/// Configures Agent provider wire format, model, endpoint, and API key.
struct AgentSettingsView: View {
    @ObservedObject private var store = LLMSettingsStore.shared
    @ObservedObject private var localization = AppLocalization.shared
    @EnvironmentObject private var runtime: AgentRuntime
    @State private var executionMode = AgentExecutionMode.ask
    @State private var provider = LLMProvider.openAICompatible
    @State private var autoCompactEnabled = LLMSettingsStore.defaultAutoCompactEnabled
    @State private var autoCompactThresholdKiB = LLMSettingsStore.defaultAutoCompactThresholdKiB
    @State private var toolCallLimit = LLMSettingsStore.defaultToolCallLimit
    @State private var riskAuthorizationEnabled = LLMSettingsStore.defaultRiskAuthorizationEnabled
    @State private var model = ""
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var activeAlert: AgentSettingsAlert?
    @State private var deletingSessions = false
    @State private var apiKeyRepresentsStoredValue = false
    @FocusState private var apiKeyFocused: Bool

    var body: some View {
        Form {
            Section(localization.text("settings.agent.history")) {
                LabeledContent(
                    localization.text("settings.agent.history.count"),
                    value: "\(runtime.history.count)"
                )
                if let metadata = runtime.currentMetadata {
                    LabeledContent(
                        localization.text("settings.agent.history.updated"),
                        value: metadata.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    LabeledContent(
                        localization.text("settings.agent.history.size"),
                        value: ByteCountFormatter.string(
                            fromByteCount: Int64(metadata.byteCount),
                            countStyle: .file
                        )
                    )
                }
                NavigationLink(localization.text("settings.agent.history.manage")) {
                    AgentSessionHistoryView()
                }
                Button(role: .destructive) {
                    activeAlert = .destructive(.deleteSessions)
                } label: {
                    HStack {
                        Label(
                            localization.text("settings.storage.agent.deleteAll"),
                            systemImage: "trash"
                        )
                        .foregroundStyle(.red)
                        Spacer()
                        if deletingSessions { ProgressView() }
                    }
                    .contentShape(Rectangle())
                }
                .disabled(deletingSessions)
                .accessibilityIdentifier("agentSettingsDeleteAllSessionsButton")
            }

            Section(localization.text("settings.agent.provider")) {
                Picker(localization.text("settings.agent.providerFormat"), selection: $provider) {
                    Text(localization.text("settings.agent.provider.openAICompatible"))
                        .tag(LLMProvider.openAICompatible)
                    Text(localization.text("settings.agent.provider.anthropicCompatible"))
                        .tag(LLMProvider.anthropicCompatible)
                }
                .accessibilityIdentifier("agentProviderFormatPicker")

                Picker(
                    localization.text("settings.agent.executionMode"),
                    selection: $executionMode
                ) {
                    Text(localization.text("settings.agent.executionMode.ask"))
                        .tag(AgentExecutionMode.ask)
                    Text(localization.text("settings.agent.executionMode.yolo"))
                        .tag(AgentExecutionMode.yolo)
                }
                .accessibilityIdentifier("agentExecutionModePicker")

                if executionMode == .yolo {
                    Text(localization.text("settings.agent.executionMode.yoloWarning"))
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Toggle(
                    localization.text("settings.agent.riskAuthorization"),
                    isOn: $riskAuthorizationEnabled
                )
                .accessibilityIdentifier("agentRiskAuthorizationToggle")
                Text(localization.text("settings.agent.riskAuthorization.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField(localization.text("settings.agent.model"), text: $model)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                    .accessibilityIdentifier("agentModelField")

                TextField(localization.text("settings.agent.baseURL"), text: $baseURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    #endif
                    .accessibilityIdentifier("agentBaseURLField")

                SecureField(localization.text("settings.agent.apiKey"), text: $apiKey)
                    .textContentType(.password)
                    .focused($apiKeyFocused)
                    .accessibilityIdentifier("agentAPIKeyField")
                    .onChange(of: apiKeyFocused) { _, focused in
                        if focused, apiKeyRepresentsStoredValue {
                            apiKey = ""
                            apiKeyRepresentsStoredValue = false
                        } else if !focused, apiKey.isEmpty, store.hasAPIKey {
                            showStoredAPIKeyMask()
                        }
                    }

            }

            Section(localization.text("settings.agent.compaction")) {
                Stepper(
                    value: $toolCallLimit,
                    in: 1...LLMSettingsStore.maximumToolCallLimit
                ) {
                    LabeledContent(
                        localization.text("settings.agent.toolCallLimit"),
                        value: "\(toolCallLimit)"
                    )
                }
                .accessibilityIdentifier("agentToolCallLimitStepper")
                Text(localization.text("settings.agent.toolCallLimit.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle(
                    localization.text("settings.agent.compaction.auto"),
                    isOn: $autoCompactEnabled
                )
                .accessibilityIdentifier("agentAutoCompactToggle")

                if autoCompactEnabled {
                    Picker(
                        localization.text("settings.agent.compaction.threshold"),
                        selection: $autoCompactThresholdKiB
                    ) {
                        ForEach(LLMSettingsStore.compactThresholdOptionsKiB, id: \.self) { value in
                            Text("\(value) KiB").tag(value)
                        }
                    }
                    .accessibilityIdentifier("agentAutoCompactThresholdPicker")
                }

                Text(localization.text("settings.agent.compaction.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    applySettings()
                } label: {
                    HStack {
                        Label(localization.text("common.apply"), systemImage: "checkmark.circle")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("agentSettingsApplyButton")

                Button(role: .destructive) {
                    activeAlert = .destructive(.clearToken)
                } label: {
                    HStack {
                        Label(
                            localization.text("settings.agent.clearToken"),
                            systemImage: "key.slash.fill"
                        )
                        .foregroundStyle(.red)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("agentSettingsClearButton")

                Button(role: .destructive) {
                    activeAlert = .destructive(.reset)
                } label: {
                    HStack {
                        Label(
                            localization.text("settings.agent.reset"),
                            systemImage: "arrow.counterclockwise.circle.fill"
                        )
                        .foregroundStyle(.red)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("agentSettingsResetButton")
            }

            Section {
                Text(localization.text("settings.agent.customHostPrivacy"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(localization.text("settings.agent"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadPersistedValues()
            Task { await runtime.refreshHistory() }
        }
        .onDisappear {
            apiKey = ""
            apiKeyRepresentsStoredValue = false
        }
        .alert(
            activeAlert.map(alertTitle) ?? "",
            isPresented: alertIsPresented,
            presenting: activeAlert
        ) { alert in
            switch alert {
            case .customHost:
                Button(localization.text("common.cancel"), role: .cancel) {}
                    .accessibilityIdentifier("agentSettingsAlertCancelButton")
                Button(localization.text("settings.agent.confirmCustomHost")) {
                    applySettings(privacyConfirmed: true)
                }
                .accessibilityIdentifier("agentSettingsCustomHostConfirmButton")
            case let .destructive(action):
                Button(localization.text("common.cancel"), role: .cancel) {}
                    .accessibilityIdentifier("agentSettingsAlertCancelButton")
                Button(localization.text("common.confirm"), role: .destructive) {
                    perform(action)
                }
                .accessibilityIdentifier("agentSettingsConfirm-\(action.rawValue)")
            case .notice:
                Button(localization.text("common.confirm")) {}
                    .accessibilityIdentifier("agentSettingsNoticeDismissButton")
            }
        } message: {
            Text(alertMessage($0))
        }
    }

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { activeAlert != nil },
            set: { if !$0 { activeAlert = nil } }
        )
    }

    private func alertTitle(_ alert: AgentSettingsAlert) -> String {
        switch alert {
        case .customHost:
            localization.text("settings.agent.confirmCustomHost")
        case .destructive(.clearToken):
            localization.text("settings.agent.clearToken")
        case .destructive(.reset):
            localization.text("settings.agent.reset")
        case .destructive(.deleteSessions):
            localization.text("settings.storage.agent.deleteAll")
        case let .notice(notice):
            notice.title
        }
    }

    private func alertMessage(_ alert: AgentSettingsAlert) -> String {
        switch alert {
        case let .customHost(host):
            "\(localization.text("settings.agent.customHostPrivacy"))\n\n"
                + localization.text("settings.agent.customHost", host)
        case .destructive(.clearToken):
            localization.text("settings.agent.clearToken.confirm")
        case .destructive(.reset):
            localization.text("settings.agent.reset.confirm")
        case .destructive(.deleteSessions):
            localization.text("settings.storage.agent.deleteAll.confirm")
        case let .notice(notice):
            notice.message
        }
    }

    private func applySettings(privacyConfirmed: Bool = false) {
        switch store.apply(
            provider: provider,
            model: model,
            baseURL: baseURL,
            apiKey: apiKeyRepresentsStoredValue ? "" : apiKey,
            executionMode: executionMode,
            autoCompactEnabled: autoCompactEnabled,
            autoCompactThresholdKiB: autoCompactThresholdKiB,
            toolCallLimit: toolCallLimit,
            riskAuthorizationEnabled: riskAuthorizationEnabled,
            privacyConfirmed: privacyConfirmed
        ) {
        case .applied:
            loadPersistedValues()
            presentNotice(
                title: localization.text("common.apply"),
                message: localization.text("settings.agent.applied")
            )
        case .invalid:
            presentNotice(
                title: localization.text("settings.agent.action.error"),
                message: localization.text("agent.state.configurationRequired")
            )
        case let .privacyConfirmationRequired(host):
            activeAlert = .customHost(host)
        }
    }

    private func loadPersistedValues() {
        provider = store.provider
        executionMode = store.executionMode
        autoCompactEnabled = store.autoCompactEnabled
        autoCompactThresholdKiB = store.autoCompactThresholdKiB
        toolCallLimit = store.toolCallLimit
        riskAuthorizationEnabled = store.riskAuthorizationEnabled
        model = store.model
        baseURL = store.baseURLString
        if store.hasAPIKey {
            showStoredAPIKeyMask()
        } else {
            apiKey = ""
            apiKeyRepresentsStoredValue = false
        }
    }

    private func perform(_ action: AgentSettingsDestructiveAction) {
        switch action {
        case .clearToken:
            let succeeded = store.clearAPIKey()
            apiKey = ""
            apiKeyRepresentsStoredValue = false
            presentNotice(
                title: localization.text(
                    succeeded ? "settings.agent.clearToken" : "settings.agent.action.error"
                ),
                message: localization.text(
                    succeeded ? "settings.agent.cleared" : "settings.agent.clearToken.error"
                )
            )
        case .reset:
            store.resetToDefaults()
            loadPersistedValues()
            presentNotice(
                title: localization.text("settings.agent.reset"),
                message: localization.text("settings.agent.resetDone")
            )
        case .deleteSessions:
            deletingSessions = true
            Task {
                do {
                    try await runtime.deleteAll()
                    presentNotice(
                        title: localization.text("settings.storage.agent.deleteAll"),
                        message: localization.text("settings.storage.agent.deleteAll.done")
                    )
                } catch {
                    presentNotice(
                        title: localization.text("settings.agent.action.error"),
                        message: localization.text("settings.storage.agent.deleteAll.error")
                    )
                }
                deletingSessions = false
            }
        }
    }

    private func presentNotice(title: String, message: String) {
        Task { @MainActor in
            await Task.yield()
            activeAlert = .notice(SettingsNotice(title: title, message: message))
        }
    }

    private func showStoredAPIKeyMask() {
        apiKey = String(repeating: "x", count: 12)
        apiKeyRepresentsStoredValue = true
    }
}


struct AgentSessionHistoryView: View {
    @EnvironmentObject private var runtime: AgentRuntime
    @ObservedObject private var localization = AppLocalization.shared

    var body: some View {
        List {

            Section {
                Button {
                    runtime.requestNewSession()
                } label: {
                    Label(localization.text("settings.agent.history.new"), systemImage: "square.and.pencil")
                }
                .disabled(runtime.isSideEffectExecuting)

                ForEach(runtime.history) { session in
                    Button {
                        runtime.requestSelectSession(session.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .foregroundStyle(.primary)
                            Text(
                                "\(session.updatedAt.formatted(date: .abbreviated, time: .shortened)) · "
                                + ByteCountFormatter.string(
                                    fromByteCount: Int64(session.byteCount),
                                    countStyle: .file
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            runtime.requestDeleteSession(session.id)
                        } label: {
                            Label(localization.text("common.delete"), systemImage: "trash")
                        }
                        .disabled(runtime.isSideEffectExecuting)
                    }
                }
            }
        }
        .navigationTitle(localization.text("settings.agent.history"))
        .task { await runtime.refreshHistory() }
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
}

private struct TextDocumentView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .default))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
