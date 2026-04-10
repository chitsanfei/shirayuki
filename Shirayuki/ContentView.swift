import SwiftUI

struct ContentView: View {
    @AppStorage("darkModeOption") private var darkModeOption: DarkModeOption = .system
    @AppStorage("videoBlockEnabled") private var videoBlockEnabled = true
    @Environment(\.colorScheme) private var systemColorScheme

    @StateObject private var store = BrowserStore(
        settings: WebRuntimeSettings(darkModeOption: .system, videoBlockEnabled: true)
    )
    
    private var effectiveDarkModeEnabled: Bool {
        switch darkModeOption {
        case .system:
            return systemColorScheme == .dark
        case .light:
            return false
        case .dark:
            return true
        }
    }

    @State private var showingSettings = false
    @State private var clearingCache = false
    @State private var cacheMessage: String?
    @State private var statusPulse: CGFloat = 0
    @State private var statusPulseTask: Task<Void, Never>?
    @State private var statusPlateVisible = true
    @State private var statusPlateHideTask: Task<Void, Never>?
    @State private var statusPlateCollapsed = false

    private var currentStatus: ReaderStatus {
        ReaderRoute.status(isLoggedIn: store.isLoggedIn, isInReader: store.isInReader)
    }

    private var mainTabs: [ShirayukiTab] {
        [.home, .categories, .games, .profile]
    }

    private var selectedTabForBar: ShirayukiTab {
        mainTabs.contains(store.selectedTab) ? store.selectedTab : .home
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            background

            ManagedWebView(store: store)
                .ignoresSafeArea(edges: .all)

            if store.isLoggedIn && !store.isInReader {
                BottomActionDock(
                    tabs: mainTabs,
                    selectedTab: selectedTabForBar,
                    onSelect: { store.navigate(to: $0) },
                    onSettingsTap: { showingSettings = true }
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if store.isInReader {
                ReaderExitButton {
                    store.exitReader()
                }
                .padding(.trailing, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            if !store.isLoggedIn {
                VStack(spacing: 12) {
                    FloatingGlassButton(
                        icon: "gearshape.fill",
                        identifier: "loggedOutSettingsButton"
                    ) {
                        showingSettings = true
                    }

                    FloatingGlassButton(
                        icon: "arrow.clockwise",
                        identifier: "refreshFloatingButton"
                    ) {
                        store.loadInitialPage()
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            if store.isLoading && !store.isInReader {
                ProgressView()
                    .tint(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 72)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false) // 不拦截点击事件
            }

            if let err = store.lastErrorMessage {
                errorCard(message: err)
            }

            if statusPlateVisible {
                TopStatusPlate(title: "Shirayuki", subtitle: currentStatus.text)
                    .padding(.top, 10)
                    .scaleEffect(statusPlateScale)
                    .offset(y: statusPlateOffsetY)
                    .blur(radius: statusPlateBlur)
                    .opacity(statusPlateOpacity)
                    .fixedSize()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false) // 不拦截点击事件
            }

            if store.isLoggedIn && !store.isInReader {
                TopBackButton {
                    store.goBack()
                }
                .padding(.leading, 16)
                .padding(.top, 11) // 和状态气泡的 .padding(.top, 10) 对齐
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(100) // 确保在最上层
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.isInReader)
        .onAppear {
            applyWebSettings()
            syncStatusPlateVisibility(for: currentStatus)
        }
        .onChange(of: darkModeOption) { _, _ in
            applyWebSettings()
        }
        .onChange(of: systemColorScheme) { _, _ in
            if darkModeOption == .system {
                applyWebSettings()
            }
        }
        .onChange(of: videoBlockEnabled) { _, _ in
            applyWebSettings()
        }
        .onChange(of: currentStatus) { _, _ in
            triggerStatusPulse()
            syncStatusPlateVisibility(for: currentStatus)
        }
        .onChange(of: store.isLoggedIn) { oldValue, newValue in
            // 登录状态变化时重新应用设置
            if !oldValue && newValue {
                // 从未登录变为已登录，延迟应用设置确保页面已加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    applyWebSettings()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            settingsView
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.06, green: 0.09, blue: 0.18), Color(red: 0.13, green: 0.09, blue: 0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [Color.white.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 320
            )
        )
        .ignoresSafeArea()
    }

    private func errorCard(message: String) -> some View {
        VStack(spacing: 8) {
            Text("网页加载异常")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
            Text("若持续白屏，请先开启 VPN 再重试登录。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
            Button("重试") {
                store.loadInitialPage()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: 320)
        .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var settingsView: some View {
        ShirayukiSettingsView(
            isPresented: $showingSettings,
            darkModeOption: $darkModeOption,
            videoBlockEnabled: $videoBlockEnabled,
            clearingCache: clearingCache,
            cacheMessage: cacheMessage,
            todayString: todayString,
            sdkDisplay: sdkDisplay,
            minimumCompatibilityDisplay: minimumCompatibilityDisplay,
            onClearCache: clearCache
        )
    }

    private func applyWebSettings() {
        store.apply(
            settings: WebRuntimeSettings(
                darkModeOption: darkModeOption,
                videoBlockEnabled: videoBlockEnabled
            )
        )
    }

    private func clearCache() {
        clearingCache = true
        cacheMessage = nil
        store.clearCache { result in
            clearingCache = false
            cacheMessage = (try? result.get()) == nil ? "清空缓存失败" : "缓存已清空"
        }
    }

    private func triggerStatusPulse() {
        statusPulseTask?.cancel()
        withAnimation(.timingCurve(0.18, 0.92, 0.32, 1.0, duration: 0.14)) {
            statusPulse = 1
        }

        statusPulseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 130_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.interpolatingSpring(stiffness: 260, damping: 23)) {
                statusPulse = 0
            }
        }
    }

    private func syncStatusPlateVisibility(for status: ReaderStatus) {
        statusPlateHideTask?.cancel()

        if status == .inReader {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                statusPlateVisible = true
                statusPlateCollapsed = false
            }

            statusPlateHideTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.timingCurve(0.22, 0.88, 0.28, 1.0, duration: 0.32)) {
                    statusPlateCollapsed = true
                }
                try? await Task.sleep(nanoseconds: 260_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    statusPlateVisible = false
                }
            }
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            statusPlateVisible = true
            statusPlateCollapsed = false
        }
    }

    private var statusPlateScale: CGFloat {
        let pulseScale = CGFloat(1.0) - (statusPulse * CGFloat(0.08))
        let collapseScale: CGFloat = statusPlateCollapsed ? 0.46 : 1.0
        return pulseScale * collapseScale
    }

    private var statusPlateOffsetY: CGFloat {
        let pulseOffset = -(statusPulse * CGFloat(6.0))
        let collapseOffset: CGFloat = statusPlateCollapsed ? -22 : 0
        return pulseOffset + collapseOffset
    }

    private var statusPlateBlur: CGFloat {
        (statusPulse * CGFloat(0.8)) + (statusPlateCollapsed ? 2.6 : 0)
    }

    private var statusPlateOpacity: Double {
        let pulseOpacity = Double(CGFloat(1.0) - (statusPulse * CGFloat(0.12)))
        let collapsedOpacity = statusPlateCollapsed ? 0.18 : 1.0
        return pulseOpacity * collapsedOpacity
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var sdkDisplay: String {
        let info = Bundle.main.infoDictionary
        if let sdkName = info?["DTSDKName"] as? String, !sdkName.isEmpty {
            return sdkName
        }
        if let platform = info?["DTPlatformName"] as? String, !platform.isEmpty {
            return platform
        }
        return "iPhoneOS (Auto)"
    }

    private var minimumCompatibilityDisplay: String {
        let info = Bundle.main.infoDictionary
        if let min = info?["MinimumOSVersion"] as? String, !min.isEmpty {
            return "iOS \(min)"
        }
        return "iOS (Auto)"
    }
}

#Preview {
    ContentView()
}
