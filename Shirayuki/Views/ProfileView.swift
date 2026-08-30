import SwiftUI

/// Presents account metadata, favorites, notifications, and settings.
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

            NavigationLink {
                OfflineComicsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.text("profile.offline"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(localization.text("profile.offline.subtitle"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 60)
            
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

/// Compact metric displayed in the profile summary.
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

/// Navigation container for application settings.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var localization = AppLocalization.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        AgentSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "sparkles",
                            title: localization.text("settings.agent"),
                            subtitle: localization.text("settings.agent.subtitle")
                        )
                    }
                    .accessibilityIdentifier("agentSettingsLink")

                    NavigationLink {
                        BlockedWordsSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "hand.raised.fill",
                            title: localization.text("settings.contentFilter"),
                            subtitle: localization.text("settings.contentFilter.subtitle")
                        )
                    }
                    .accessibilityIdentifier("contentFilterSettingsLink")

                    NavigationLink {
                        AppearanceSettingsView(viewModel: viewModel)
                    } label: {
                        SettingsCategoryRow(
                            icon: "paintbrush.fill",
                            title: localization.text("settings.appearance"),
                            subtitle: localization.text("settings.appearance.subtitle")
                        )
                    }
                    .accessibilityIdentifier("appearanceSettingsLink")

                    NavigationLink {
                        RankSettingsView(viewModel: viewModel)
                    } label: {
                        SettingsCategoryRow(
                            icon: "chart.bar.xaxis",
                            title: localization.text("settings.rank.title"),
                            subtitle: localization.text("settings.rank.subtitle")
                        )
                    }

                    NavigationLink {
                        ReadingSettingsView(viewModel: viewModel)
                    } label: {
                        SettingsCategoryRow(
                            icon: "book.pages.fill",
                            title: localization.text("settings.reading"),
                            subtitle: localization.text("settings.reading.subtitle")
                        )
                    }

                    NavigationLink {
                        NetworkSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "network",
                            title: localization.text("settings.network"),
                            subtitle: localization.text("settings.network.subtitle")
                        )
                    }

                    NavigationLink {
                        StorageSettingsView(viewModel: viewModel)
                    } label: {
                        SettingsCategoryRow(
                            icon: "externaldrive.fill",
                            title: localization.text("settings.cache"),
                            subtitle: localization.text("settings.cache.subtitle")
                        )
                    }
                    .accessibilityIdentifier("storageSettingsLink")

                    NavigationLink {
                        SourceSettingsView(viewModel: viewModel)
                    } label: {
                        SettingsCategoryRow(
                            icon: "chevron.left.forwardslash.chevron.right",
                            title: localization.text("settings.source"),
                            subtitle: localization.text("settings.source.subtitle")
                        )
                    }

                    NavigationLink {
                        AboutSettingsView(viewModel: viewModel)
                    } label: {
                        SettingsCategoryRow(
                            icon: "info.circle.fill",
                            title: localization.text("settings.about"),
                            subtitle: localization.text("settings.about.subtitle")
                        )
                    }
                }
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
        .accessibilityIdentifier("settingsSheet")
        .agentSettingsSuppressed()
    }

}
