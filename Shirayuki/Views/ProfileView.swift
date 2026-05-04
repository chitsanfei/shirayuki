import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var localization = AppLocalization.shared
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let user = viewModel.userProfile {
                        profileHeader(user: user)
                        statsSection(user: user)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .padding(.horizontal, 16)
                    } else if let errorMessage = viewModel.errorMessage {
                        contentErrorState(message: errorMessage)
                    }
                    
                    favoritesSection
                    menuSection
                }
                .padding(.vertical, 16)
                .padding(.bottom, 120)
            }
            .navigationTitle(localization.text("profile.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await viewModel.loadProfile()
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
        }
        .task {
            guard viewModel.userProfile == nil else { return }
            await viewModel.loadProfile()
        }
    }
    
    private func profileHeader(user: UserProfileResponse) -> some View {
        ZStack(alignment: .topLeading) {
            if let avatarURL = user.avatar?.url {
                ComicCoverImage(url: avatarURL)
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 20)
                    .overlay(Color.black.opacity(0.3))
            } else {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.4), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            HStack(alignment: .center, spacing: 16) {
                avatarView(user: user)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(user.name.isEmpty ? localization.text("profile.unnamed") : user.name)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    
                    Text(localization.text("profile.levelExp", user.level, user.exp))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    
                    if !user.slogan.isEmpty {
                        Text(user.slogan)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 132)
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    private func avatarView(user: UserProfileResponse) -> some View {
        Group {
            if let avatarURL = user.avatar?.url {
                ComicCoverImage(url: avatarURL)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                    Text(String((user.name.isEmpty ? "U" : user.name).prefix(1)))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 76, height: 76)
        .background(Circle().fill(Color.white.opacity(0.12)))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func statsSection(user: UserProfileResponse) -> some View {
        HStack(spacing: 0) {
            StatItem(value: "\(user.exp)", label: localization.text("profile.stats.exp"))
            Divider().frame(height: 42)
            StatItem(value: "\(user.comicsUploaded)", label: localization.text("profile.stats.upload"))
            Divider().frame(height: 42)
            StatItem(value: favoriteStatValue, label: localization.text("profile.stats.favorites"))
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private var favoritesSection: some View {
        SettingsBlock(title: localization.text("profile.section.content")) {
            NavigationLink(destination: ComicsBrowserView(source: .favorites)) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.pink)
                        .frame(width: 32, height: 32)
                        .background(Color.pink.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.text("profile.favorites.entry"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(favoriteSubtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(localization.text("profile.favorites.browse"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private var favoriteStatValue: String {
        guard let total = viewModel.favoriteTotalCount else { return "—" }
        return "\(total)"
    }

    private var favoriteSubtitle: String {
        guard let total = viewModel.favoriteTotalCount else {
            return localization.text("profile.favorites.unavailable")
        }
        guard total > 0 else {
            return localization.text("profile.favorites.empty")
        }
        return localization.text("profile.favorites.syncedCount", total)
    }

    private var menuSection: some View {
        SettingsBlock(title: localization.text("profile.section.features")) {
            if let user = viewModel.userProfile {
                MenuTile(
                    icon: user.isPunched ? "checkmark.seal.fill" : "calendar.badge.plus",
                    title: user.isPunched ? localization.text("profile.punch.done") : localization.text("profile.punch.action"),
                    subtitle: user.isPunched ? localization.text("profile.punch.done.subtitle") : localization.text("profile.punch.action.subtitle")
                ) {
                    Task {
                        await viewModel.punchIn()
                    }
                }
                Divider().padding(.leading, 60)
            }
            
            MenuTile(
                icon: "gearshape.fill",
                title: localization.text("profile.settings"),
                subtitle: localization.text("profile.settings.subtitle")
            ) {
                showSettings = true
            }
            Divider().padding(.leading, 60)
            MenuTile(
                icon: "arrow.right.square.fill",
                title: localization.text("profile.logout"),
                subtitle: localization.text("profile.logout.subtitle")
            ) {
                viewModel.logout()
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func contentErrorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(localization.text("common.reload")) {
                Task {
                    await viewModel.loadProfile()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(.horizontal, 16)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var localization = AppLocalization.shared
    
    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                networkSection
                cacheSection
                sourceSection
                aboutSection
            }
            .navigationTitle(localization.text("settings.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.text("common.done")) { dismiss() }
                }
            }
        }
    }

    private var themeModeBinding: Binding<AppThemeMode> {
        Binding(
            get: { viewModel.themeMode },
            set: { viewModel.setThemeMode($0) }
        )
    }

    private var appearanceSection: some View {
        Section(localization.text("settings.appearance")) {
            Picker(localization.text("settings.theme"), selection: themeModeBinding) {
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

    private var networkSection: some View {
        Section(localization.text("settings.network")) {
            ForEach(APIEndpoint.allCases) { endpoint in
                Button {
                    viewModel.setEndpoint(endpoint)
                } label: {
                    endpointRow(endpoint)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cacheSection: some View {
        Section(localization.text("settings.cache")) {
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

            if let cacheMessage = viewModel.cacheMessage {
                Text(cacheMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sourceSection: some View {
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
                    Label(localization.text("settings.repository"), systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            NavigationLink(localization.text("settings.license")) {
                ScrollView {
                    Text(viewModel.licenseText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle(localization.text("settings.license"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
            }

            NavigationLink(localization.text("settings.references")) {
                ScrollView {
                    Text(viewModel.thirdPartyNoticesText)
                        .font(.system(.body, design: .default))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle(localization.text("settings.references"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
            }
        }
    }

    private var aboutSection: some View {
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

    private func endpointRow(_ endpoint: APIEndpoint) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(endpoint.displayName)
                    .foregroundStyle(.primary)
                Text(endpoint.description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            if viewModel.selectedEndpoint == endpoint {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
