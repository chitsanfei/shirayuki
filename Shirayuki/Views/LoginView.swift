import SwiftUI

struct LoginView: View {
    @StateObject private var appState = AppState.shared
    @ObservedObject private var localization = AppLocalization.shared
    @State private var username = SavedLoginCredentialStore.savedUsername
    @State private var password = SavedLoginCredentialStore.savedPassword()
    @State private var rememberPassword = SavedLoginCredentialStore.shouldRememberPassword
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                
                AppBrandIcon(size: 96, cornerRadius: 26)
                
                VStack(spacing: 8) {
                    Text("Shirayuki")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    
                    Text(localization.text("auth.subtitle"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                        TextField(localization.text("auth.username"), text: $username)
                            .textContentType(.username)
                            #if os(iOS)
                            .autocapitalization(.none)
                            #endif
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                        SecureField(localization.text("auth.password"), text: $password)
                            .textContentType(.password)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }

                Toggle(isOn: $rememberPassword) {
                    Text(localization.text("auth.rememberPassword"))
                        .font(.system(size: 15, weight: .medium))
                }
                .toggleStyle(.switch)

                Menu {
                    ForEach(APIEndpoint.allCases) { endpoint in
                        Button {
                            appState.setAPIEndpoint(endpoint)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(endpoint.displayName)
                                Text(endpoint.description)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "network")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(localization.text("auth.network"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(appState.apiEndpoint.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                            Text(appState.apiEndpoint.description)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    Task {
                        do {
                            try await appState.login(username: username, password: password)
                            SavedLoginCredentialStore.save(
                                username: username,
                                password: password,
                                rememberPassword: rememberPassword
                            )
                        } catch {
                            if !rememberPassword {
                                SavedLoginCredentialStore.clearSavedPassword()
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if appState.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(localization.text("auth.login"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(username.isEmpty || password.isEmpty || appState.isLoading)
                .opacity(username.isEmpty || password.isEmpty ? 0.6 : 1)
                
                if let error = appState.errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding(.horizontal, 28)
            .navigationTitle("")
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .onChange(of: rememberPassword) { _, newValue in
                if !newValue {
                    SavedLoginCredentialStore.clearSavedPassword()
                }
            }
        }
    }
}
