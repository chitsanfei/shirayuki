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

    private let dockHeight: CGFloat = 64
    private let itemHeight: CGFloat = 50
    private let searchSize: CGFloat = 58
    private let spacing: CGFloat = 10
    private let dockInset: CGFloat = 8
    private let itemSpacing: CGFloat = 6
    @Namespace private var selectionNamespace

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, CGFloat(0))
            let dockWidth = max(CGFloat(0), width - searchSize - spacing)
            let itemCount = CGFloat(tabs.count + 1)
            let itemWidth = max(
                CGFloat(48),
                (dockWidth - dockInset * 2 - itemSpacing * max(itemCount - 1, CGFloat(0))) / max(itemCount, CGFloat(1))
            )

            HStack(spacing: spacing) {
                ZStack {
                    Capsule()
                        .fill(.clear)
                        .frame(width: dockWidth, height: dockHeight)
                        .glassEffect(.regular.interactive(), in: .capsule)

                    HStack(spacing: itemSpacing) {
                        ForEach(tabs, id: \.self) { tab in
                            itemButton(
                                title: tab.title,
                                image: tab.systemImage,
                                selected: selectedTab == tab,
                                width: itemWidth
                            ) {
                                onSelect(tab)
                            }
                            .accessibilityIdentifier("tab_\(tab.rawValue)")
                        }

                        itemButton(
                            title: "设置",
                            image: "gearshape.fill",
                            selected: false,
                            width: itemWidth,
                            action: onSettingsTap
                        )
                        .accessibilityIdentifier("settingsButton")
                    }
                    .padding(.horizontal, dockInset)
                }

                Button {
                    onSelect(.search)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: searchSize, height: searchSize)
                        .scaleEffect(selectedTab == .search ? 1.06 : 1.0)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityIdentifier("searchFloatingButton")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedTab)
        }
        .frame(height: searchSize)
        .accessibilityIdentifier("bottomBar")
    }

    private func itemButton(
        title: String,
        image: String,
        selected: Bool,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if selected {
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.18), lineWidth: 0.6)
                        )
                        .shadow(color: .white.opacity(0.08), radius: 4, y: -1)
                        .padding(.vertical, 2)
                        .matchedGeometryEffect(id: "dockSelection", in: selectionNamespace)
                }

                VStack(spacing: 2) {
                    Image(systemName: image)
                        .font(.system(size: selected ? 17 : 16, weight: selected ? .bold : .semibold))
                    Text(title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .scaleEffect(selected ? 1.03 : 1.0)
            }
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.72))
            .frame(width: width, height: itemHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
