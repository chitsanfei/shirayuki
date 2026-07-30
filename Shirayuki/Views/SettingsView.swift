import SwiftUI

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

struct AppearanceSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var localization = AppLocalization.shared

    var body: some View {
        Form {
            Section(localization.text("settings.appearance")) {
                Picker(
                    localization.text("settings.theme"),
                    selection: Binding(
                        get: { viewModel.themeMode },
                        set: { viewModel.setThemeMode($0) }
                    )
                ) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
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
}

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

struct StorageSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var localization = AppLocalization.shared

    var body: some View {
        Form {
            Section(localization.text("settings.cache")) {
                StorageUsageBar(
                    cacheBytes: viewModel.imageCacheSize,
                    offlineBytes: viewModel.offlineStorageSize
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
                        if viewModel.isClearingCache {
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isClearingCache)

                NavigationLink(localization.text("settings.storage.offline.manage")) {
                    OfflineComicsView()
                }

                Button(role: .destructive) {
                    viewModel.clearOfflineStorage()
                } label: {
                    Text(localization.text("settings.storage.offline.clear"))
                }

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
        .task { viewModel.refreshStorageUsage() }
    }
}

private struct StorageUsageBar: View {
    let cacheBytes: Int
    let offlineBytes: Int

    private var total: Int { max(cacheBytes + offlineBytes, 1) }

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
