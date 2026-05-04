import SwiftUI

private enum ReaderLayout {
    static let bottomToolbarVisibleOffset: CGFloat = 158
    static let bottomToolbarHiddenOffset: CGFloat = 22
}

struct ReaderView: View {
    @StateObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showChapterSheet = false
    @State private var showReaderSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                readerContent
                
                if viewModel.showPageNumbers && !viewModel.images.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            PageNumberTag(text: "\(viewModel.currentPageIndex + 1) / \(viewModel.images.count)")
                                .padding(.leading, 16)
                                .padding(.bottom, shouldShowBottomToolbar ? geometry.safeAreaInsets.bottom + ReaderLayout.bottomToolbarVisibleOffset : geometry.safeAreaInsets.bottom + ReaderLayout.bottomToolbarHiddenOffset)
                            Spacer()
                        }
                    }
                }
                
                ReaderTopToolbar(
                    viewModel: viewModel,
                    topInset: geometry.safeAreaInsets.top,
                    isVisible: shouldShowTopToolbar,
                    onBack: closeReader,
                    onSettings: { showReaderSettings = true }
                )
                
                ReaderBottomToolbar(
                    viewModel: viewModel,
                    bottomInset: geometry.safeAreaInsets.bottom,
                    isVisible: shouldShowBottomToolbar,
                    onChapterTap: { showChapterSheet = true }
                )
            }
            .ignoresSafeArea()
            #if os(iOS)
            .statusBar(hidden: !shouldShowTopToolbar)
            #endif
            .sheet(isPresented: $showChapterSheet) {
                ChapterListSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showReaderSettings) {
                ReaderSettingsSheet(viewModel: viewModel)
            }
            .task {
                viewModel.startInitialLoadIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .inactive, .background:
                    viewModel.persistProgressNow()
                case .active:
                    break
                @unknown default:
                    break
                }
            }
            .onDisappear {
                viewModel.cancelOngoingWork()
            }
        }
    }

    @ViewBuilder
    private var readerContent: some View {
        if !viewModel.images.isEmpty {
            Group {
                switch viewModel.readMode {
                case .vertical:
                    VerticalReader(viewModel: viewModel)
                case .horizontal:
                    HorizontalReader(viewModel: viewModel)
                }
            }
        } else if viewModel.isLoading {
            ReaderLoadingState(onClose: closeReader)
        } else if let errorMessage = viewModel.errorMessage {
            ReaderErrorState(
                message: errorMessage,
                retry: viewModel.retryInitialLoad,
                onClose: closeReader
            )
        } else {
            ReaderLoadingState(onClose: closeReader)
        }
    }

    private var shouldShowTopToolbar: Bool {
        viewModel.showToolbar || viewModel.images.isEmpty || viewModel.isLoading || viewModel.errorMessage != nil
    }

    private var shouldShowBottomToolbar: Bool {
        viewModel.showToolbar && !viewModel.images.isEmpty
    }

    private func closeReader() {
        viewModel.cancelOngoingWork()
        dismiss()
    }
}

private struct ReaderPageFrame: Equatable {
    let index: Int
    let frame: CGRect
}

private struct ReaderPageFramePreferenceKey: PreferenceKey {
    static var defaultValue: [ReaderPageFrame] = []
    
    static func reduce(value: inout [ReaderPageFrame], nextValue: () -> [ReaderPageFrame]) {
        value.append(contentsOf: nextValue())
    }
}

struct VerticalReader: View {
    @ObservedObject var viewModel: ReaderViewModel
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.images.enumerated()), id: \.element.uid) { index, image in
                            ComicAsyncImage(url: image.url)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .scaleEffect(scale)
                                .id(index)
                                .background {
                                    GeometryReader { pageGeometry in
                                        Color.clear.preference(
                                            key: ReaderPageFramePreferenceKey.self,
                                            value: [
                                                ReaderPageFrame(
                                                    index: index,
                                                    frame: pageGeometry.frame(in: .named("readerVerticalScroll"))
                                                )
                                            ]
                                        )
                                    }
                                }
                        }
                    }
                }
                .coordinateSpace(name: "readerVerticalScroll")
                .onPreferenceChange(ReaderPageFramePreferenceKey.self) { frames in
                    updateCurrentPage(using: frames, viewportHeight: geometry.size.height)
                }
                .onChange(of: viewModel.scrollTargetPage) { _, target in
                    guard let target else { return }
                    withAnimation(.easeInOut(duration: 0.22)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    Task { @MainActor in
                        viewModel.scrollTargetPage = nil
                    }
                }
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    withAnimation(.spring(response: 0.3)) {
                        scale = scale > 1.0 ? 1.0 : 2.0
                    }
                    lastScale = scale
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = lastScale * value
                }
                .onEnded { _ in
                    if scale < 1.0 {
                        withAnimation { scale = 1.0 }
                    }
                    lastScale = scale
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    viewModel.toggleToolbar()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { _ in
                    if viewModel.showToolbar {
                        viewModel.hideToolbar()
                    }
                }
        )
    }
    
    private func updateCurrentPage(using frames: [ReaderPageFrame], viewportHeight: CGFloat) {
        guard !frames.isEmpty else { return }
        let targetY = viewportHeight * 0.35
        let visibleFrames = frames.filter { $0.frame.maxY > 0 && $0.frame.minY < viewportHeight }
        let candidates = visibleFrames.isEmpty ? frames : visibleFrames
        guard let nearest = candidates.min(by: {
            abs($0.frame.midY - targetY) < abs($1.frame.midY - targetY)
        }) else { return }
        
        if nearest.index != viewModel.currentPageIndex {
            viewModel.currentPageIndex = nearest.index
            viewModel.preloadAdjacentImages()
        }
    }
}

struct HorizontalReader: View {
    @ObservedObject var viewModel: ReaderViewModel
    
    var body: some View {
        TabView(
            selection: Binding(
                get: { viewModel.currentPageIndex },
                set: { newValue in
                    viewModel.currentPageIndex = newValue
                    viewModel.preloadAdjacentImages()
                }
            )
        ) {
            ForEach(Array(viewModel.images.enumerated()), id: \.element.uid) { index, image in
                ZoomableComicImage(url: image.url) {
                    viewModel.toggleToolbar()
                }
                .tag(index)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .ignoresSafeArea()
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { _ in
                    if viewModel.showToolbar {
                        viewModel.hideToolbar()
                    }
                }
        )
    }
}

struct ZoomableComicImage: View {
    let url: String
    let onSingleTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { _ in
            ComicAsyncImage(url: url)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            if scale < 1.0 {
                                withAnimation(.spring()) {
                                    scale = 1.0
                                    offset = .zero
                                }
                            }
                            lastScale = scale
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring(response: 0.3)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                }
                                lastScale = scale
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded(onSingleTap)
                )
        }
    }
}

struct ReaderTopToolbar: View {
    @ObservedObject var viewModel: ReaderViewModel
    let topInset: CGFloat
    let isVisible: Bool
    let onBack: () -> Void
    let onSettings: () -> Void
    
    private var titleText: String {
        if !viewModel.currentChapterTitle.isEmpty {
            return viewModel.currentChapterTitle
        }
        return viewModel.currentChapter?.title ?? viewModel.comic.title
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                ReaderToolbarIconButton(systemImage: "chevron.left", action: onBack)

                ReaderGlassPanel(horizontalPadding: 16, verticalPadding: 14) {
                    VStack(spacing: 4) {
                        Text(titleText)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(viewModel.readMode.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 10) {
                    Menu {
                        ForEach(ReadMode.allCases) { mode in
                            Button {
                                viewModel.readMode = mode
                            } label: {
                                Label(mode.displayName, systemImage: viewModel.readMode == mode ? "checkmark" : "")
                            }
                        }
                    } label: {
                        ReaderToolbarOrb(systemImage: "book.pages")
                    }
                    
                    ReaderToolbarIconButton(systemImage: "gearshape.fill", action: onSettings)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, topInset + 8)
            
            Spacer()
        }
        .offset(y: isVisible ? 0 : -(topInset + 140))
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.96, anchor: .top)
        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: isVisible)
    }
}

struct ReaderBottomToolbar: View {
    @ObservedObject var viewModel: ReaderViewModel
    let bottomInset: CGFloat
    let isVisible: Bool
    let onChapterTap: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            if !viewModel.images.isEmpty {
                ReaderGlassPanel(horizontalPadding: 18, verticalPadding: 18) {
                    VStack(spacing: 16) {
                        HStack {
                            Text("\(viewModel.currentPageIndex + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("/ \(viewModel.images.count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        if viewModel.images.count > 1 {
                            Slider(
                                value: Binding(
                                    get: { Double(viewModel.currentPageIndex) },
                                    set: { viewModel.seekToPage(Int($0.rounded())) }
                                ),
                                in: 0...Double(viewModel.images.count - 1),
                                step: 1
                            )
                            .tint(.white)
                        } else {
                            Capsule()
                                .fill(Color.white.opacity(0.14))
                                .frame(height: 6)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: 44, height: 6)
                                }
                        }
                        
                        HStack(spacing: 14) {
                            ReaderToolbarIconButton(
                                systemImage: "backward.end.fill",
                                isDisabled: viewModel.isFirstChapter
                            ) {
                                Task { await viewModel.goPreviousChapter() }
                            }
                            
                            ReaderToolbarIconButton(systemImage: "list.bullet", action: onChapterTap)
                            
                            ReaderToolbarIconButton(
                                systemImage: viewModel.isAutoTurning ? "pause.fill" : "play.fill"
                            ) {
                                if viewModel.isAutoTurning {
                                    viewModel.stopAutoTurn()
                                } else {
                                    viewModel.startAutoTurn()
                                }
                            }
                            
                            ReaderToolbarIconButton(
                                systemImage: viewModel.isMenuLocked ? "lock.fill" : "lock.open.fill",
                                tint: viewModel.isMenuLocked ? .blue : .white
                            ) {
                                viewModel.toggleLockMenu()
                            }
                            
                            ReaderToolbarIconButton(
                                systemImage: "forward.end.fill",
                                isDisabled: viewModel.isLastChapter
                            ) {
                                Task { await viewModel.goNextChapter() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, bottomInset + 12)
            }
        }
        .offset(y: isVisible ? 0 : 240)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.96, anchor: .bottom)
        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: isVisible)
    }
}

struct ChapterListSheet: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.chapters.enumerated()), id: \.element.uid) { index, chapter in
                    Button {
                        Task {
                            await viewModel.goToChapter(index)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(chapter.title)
                                .foregroundStyle(viewModel.currentChapterIndex == index ? Color.accentColor : .primary)
                            Spacer()
                            if viewModel.currentChapterIndex == index {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(AppLocalization.text("reader.chapterList"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.text("common.done")) { dismiss() }
                }
            }
        }
    }
}

struct ReaderSettingsSheet: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalization.text("reader.settings.direction")) {
                    Picker(AppLocalization.text("reader.settings.direction.label"), selection: $viewModel.readMode) {
                        ForEach(ReadMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(AppLocalization.text("reader.settings.display")) {
                    Toggle(AppLocalization.text("reader.settings.showPageNumbers"), isOn: $viewModel.showPageNumbers)
                    Toggle(AppLocalization.text("reader.settings.lockMenu"), isOn: $viewModel.isMenuLocked)
                }
                
                Section(AppLocalization.text("reader.settings.autoTurn")) {
                    if viewModel.isAutoTurning {
                        Button(AppLocalization.text("reader.settings.autoTurn.stop")) {
                            viewModel.stopAutoTurn()
                        }
                        .foregroundStyle(.red)
                    } else {
                        Button(AppLocalization.text("reader.settings.autoTurn.start")) {
                            viewModel.startAutoTurn()
                        }
                    }
                    
                    HStack {
                        Text(AppLocalization.text("reader.settings.autoTurn.interval"))
                        Spacer()
                        Slider(value: $viewModel.autoTurnInterval, in: 2...60, step: 1)
                            .frame(width: 180)
                        Text("\(Int(viewModel.autoTurnInterval))s")
                            .font(.system(size: 14, weight: .medium))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .navigationTitle(AppLocalization.text("reader.settings.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.text("common.done")) { dismiss() }
                }
            }
        }
    }
}

private struct ReaderErrorState: View {
    let message: String
    let retry: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            HStack(spacing: 12) {
                Button(AppLocalization.text("reader.close"), action: onClose)
                    .buttonStyle(.bordered)
                Button(AppLocalization.text("common.reload"), action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .background(ReaderGlassPanelBackground())
        .padding(.horizontal, 24)
    }
}

private struct ReaderLoadingState: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.25)
            Text(AppLocalization.text("reader.loading.title"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(AppLocalization.text("reader.loading.subtitle"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
            Button(AppLocalization.text("reader.close"), action: onClose)
                .buttonStyle(.bordered)
                .tint(.white)
        }
        .padding(28)
        .background(ReaderGlassPanelBackground())
        .padding(.horizontal, 24)
    }
}

private struct ReaderGlassPanel<Content: View>: View {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let content: Content

    init(
        horizontalPadding: CGFloat = 14,
        verticalPadding: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(ReaderGlassPanelBackground())
    }
}

private struct ReaderGlassPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.24), radius: 20, x: 0, y: 8)
    }
}

private struct ReaderToolbarOrb: View {
    let systemImage: String
    var tint: Color = .white
    var isDisabled = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle((isDisabled ? Color.white.opacity(0.28) : tint))
            .frame(width: 46, height: 46)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
    }
}

private struct ReaderToolbarIconButton: View {
    let systemImage: String
    var tint: Color = .white
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ReaderToolbarOrb(systemImage: systemImage, tint: tint, isDisabled: isDisabled)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
