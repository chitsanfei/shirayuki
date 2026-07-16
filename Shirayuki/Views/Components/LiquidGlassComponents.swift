import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Comic Cover Image
struct ComicCoverImage: View {
    let url: String?
    var contentMode: ContentMode = .fill
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay {
                ComicAsyncImage(url: url)
                    .modifier(ComicImageScaling(contentMode: contentMode))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .clipped()
    }
}

struct ComicAsyncImage: View {
    let url: String?
    let offlineComicID: String?
    let offlineChapterID: String?
    let expectedOfflineImageCount: Int?
    let forceOffline: Bool
    @State private var imageData: Data?
    @State private var isLoading = false
    @State private var didFail = false

    private var requestID: String {
        "\(url ?? "empty")|\(AppImageQuality.stored.rawValue)|\(offlineComicID ?? "")|\(offlineChapterID ?? "")|\(expectedOfflineImageCount ?? 0)"
    }

    init(
        url: String?,
        offlineComicID: String? = nil,
        offlineChapterID: String? = nil,
        expectedOfflineImageCount: Int? = nil,
        forceOffline: Bool = false
    ) {
        self.url = url
        self.offlineComicID = offlineComicID
        self.offlineChapterID = offlineChapterID
        self.expectedOfflineImageCount = expectedOfflineImageCount
        self.forceOffline = forceOffline
    }
    
    var body: some View {
        Group {
            if let data = imageData {
                #if canImport(UIKit)
                if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                } else {
                    placeholder
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                } else {
                    placeholder
                }
                #else
                placeholder
                #endif
            } else {
                placeholder
            }
        }
        .task(id: requestID) {
            imageData = nil
            didFail = false
            guard let url = url else {
                isLoading = false
                return
            }
            isLoading = true
            do {
                let quality = AppImageQuality.stored
                if (forceOffline || !AppReaderSettingsStore.shared.ignoresOfflineContent),
                   let comicID = offlineComicID,
                   let chapterID = offlineChapterID,
                   let localData = await OfflineComicStore.shared.imageData(
                       comicID: comicID,
                       chapterID: chapterID,
                       url: url,
                       quality: quality,
                       expectedImageCount: expectedOfflineImageCount
                   ) {
                    imageData = localData
                } else {
                    imageData = try await ImageLoader.shared.loadImage(from: url, quality: quality)
                }
            } catch {
                imageData = nil
                didFail = true
            }
            isLoading = false
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(10)
                    .background(.black.opacity(0.22), in: Circle())
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
            } else if didFail && imageData == nil {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
        }
        .animation(.interpolatingSpring(stiffness: 240, damping: 22), value: imageData != nil)
        .animation(.easeOut(duration: 0.18), value: isLoading)
    }
    
    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(0.12)
            if !isLoading && !didFail {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
    }
}

private struct ComicImageScaling: ViewModifier {
    let contentMode: ContentMode

    func body(content: Content) -> some View {
        switch contentMode {
        case .fill:
            content.scaledToFill()
        case .fit:
            content.scaledToFit()
        }
    }
}

// MARK: - Glass Toolbar Background
struct GlassToolbarBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

// MARK: - Page Number Tag
struct PageNumberTag: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                }
            )
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Settings Block
struct SettingsBlock<Content: View>: View {
    let title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Menu Tile
struct MenuTile: View {
    let icon: String
    let title: String
    let subtitle: String?
    let value: String?
    let action: (() -> Void)?
    
    init(icon: String, title: String, subtitle: String? = nil, value: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.action = action
    }
    
    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
