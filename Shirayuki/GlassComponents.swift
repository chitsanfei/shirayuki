import SwiftUI

struct TopStatusPlate: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minWidth: 112, minHeight: 46)
        .fixedSize()
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityIdentifier("statusPlate")
    }
}

struct BottomActionDock: View {
    let tabs: [ShirayukiTab]
    let selectedTab: ShirayukiTab
    let onSelect: (ShirayukiTab) -> Void
    let onSettingsTap: () -> Void

    private enum DockAction: Hashable {
        case tab(ShirayukiTab)
        case settings
    }

    private let dockHeight: CGFloat = 62
    private let itemHeight: CGFloat = 50
    private let searchSize: CGFloat = 58
    private let spacing: CGFloat = 10
    private let itemSpacing: CGFloat = 6
    @Namespace private var selectionNamespace
    @State private var lensActive = false
    @State private var dragMode = false

    private var actions: [DockAction] {
        tabs.map { .tab($0) } + [.settings]
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: spacing) {
                ZStack {
                    Capsule()
                        .fill(.clear)
                        .frame(height: dockHeight)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.14), lineWidth: 0.6)
                        }

                    HStack(spacing: itemSpacing) {
                        ForEach(actions, id: \.self) { action in
                            dockItem(action)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)
                    .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.84), value: selectedTab)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Capsule(style: .continuous))
                .simultaneousGesture(
                    dockDragGesture(
                        totalWidth: max(0, proxy.size.width - searchSize - spacing),
                        itemCount: actions.count
                    )
                )

                Button {
                    onSelect(.search)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selectedTab == .search ? .blue : .white.opacity(0.9))
                        .frame(width: searchSize, height: searchSize)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityIdentifier("searchFloatingButton")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: searchSize)
        .onChange(of: selectedTab) { _, _ in
            if !dragMode {
                lensActive = false
            }
        }
        .accessibilityIdentifier("bottomBar")
    }

    @ViewBuilder
    private func dockItem(_ action: DockAction) -> some View {
        let selected = isSelected(action)
        let title = title(for: action)
        let image = image(for: action)

        Button {
            lensActive = false
            withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.84)) {
                trigger(action)
            }
        } label: {
            ZStack {
                if selected {
                    selectionLens(active: lensActive)
                        .matchedGeometryEffect(id: "dockSelection", in: selectionNamespace)
                }

                VStack(spacing: 2) {
                    Image(systemName: image)
                        .font(.system(size: selected ? 18 : 16, weight: selected ? .bold : .semibold))
                    Text(title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .scaleEffect(selected ? (lensActive ? 1.12 : 1.04) : 1.0)
            }
            .foregroundStyle(selected ? .blue : .white.opacity(0.88))
            .frame(height: itemHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.22)
                .onEnded { _ in
                    guard selected else { return }
                    dragMode = true
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                        lensActive = true
                    }
                }
        )
        .accessibilityIdentifier(accessibilityID(for: action))
    }

    @ViewBuilder
    private func selectionLens(active: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.clear)
                .glassEffect(
                    .regular
                        .tint(active ? .blue.opacity(0.22) : .blue.opacity(0.12))
                        .interactive(),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(active ? .blue.opacity(0.55) : .blue.opacity(0.38), lineWidth: active ? 1.1 : 0.8)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(active ? 0.34 : 0.18),
                            .white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
        }
        .shadow(color: .blue.opacity(active ? 0.32 : 0.18), radius: active ? 18 : 10, y: 4)
        .padding(.vertical, 2)
    }

    private func isSelected(_ action: DockAction) -> Bool {
        switch action {
        case .tab(let tab):
            return selectedTab == tab
        case .settings:
            return false
        }
    }

    private func trigger(_ action: DockAction) {
        switch action {
        case .tab(let tab):
            onSelect(tab)
        case .settings:
            onSettingsTap()
        }
    }

    private func title(for action: DockAction) -> String {
        switch action {
        case .tab(let tab):
            return tab.title
        case .settings:
            return "设置"
        }
    }

    private func image(for action: DockAction) -> String {
        switch action {
        case .tab(let tab):
            return tab.systemImage
        case .settings:
            return "gearshape.fill"
        }
    }

    private func accessibilityID(for action: DockAction) -> String {
        switch action {
        case .tab(let tab):
            return "tab_\(tab.rawValue)"
        case .settings:
            return "settingsButton"
        }
    }

    private func dockDragGesture(totalWidth: CGFloat, itemCount: Int) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard lensActive || dragMode else { return }
                dragMode = true
                updateLensTarget(
                    locationX: value.location.x,
                    totalWidth: totalWidth,
                    itemCount: itemCount
                )
            }
            .onEnded { _ in
                dragMode = false
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    lensActive = false
                }
            }
    }

    private func updateLensTarget(locationX: CGFloat, totalWidth: CGFloat, itemCount: Int) {
        let horizontalInset: CGFloat = 8
        let usableWidth = max(1, totalWidth - horizontalInset * 2)
        let relativeX = min(max(locationX - horizontalInset, 0), usableWidth - 0.001)
        let slotWidth = usableWidth / CGFloat(max(itemCount, 1))
        let slotIndex = min(max(Int(relativeX / slotWidth), 0), itemCount - 1)

        guard slotIndex < tabs.count else { return }
        let target = tabs[slotIndex]
        guard target != selectedTab else { return }

        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.82)) {
            onSelect(target)
        }
    }
}

struct FloatingGlassButton: View {
    let icon: String
    let identifier: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 58, height: 58)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityIdentifier(identifier)
    }
}

struct TopBackButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityIdentifier("topBackButton")
    }
}

struct ReaderExitButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label("退出阅读", systemImage: "xmark.circle.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityIdentifier("exitReaderButton")
    }
}
