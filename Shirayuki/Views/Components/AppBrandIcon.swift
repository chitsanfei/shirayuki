import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#endif

struct AppBrandIcon: View {
    var size: CGFloat = 88
    var cornerRadius: CGFloat = 22

    var body: some View {
        Group {
            if let image = AppBrandIconSource.image {
                #if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                #elseif canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                #endif
            } else {
                Image(systemName: "book.closed.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.22)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
        }
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}

private enum AppBrandIconSource {
    static var image: PlatformImage? {
        #if canImport(UIKit)
        if let name = iconName, let image = UIImage(named: name) {
            return image
        }
        return UIImage(named: "light") ?? UIImage(named: "night")
        #elseif canImport(AppKit)
        if let name = iconName, let image = NSImage(named: name) {
            return image
        }
        return NSImage(named: "light") ?? NSImage(named: "night")
        #endif
    }

    private static var iconName: String? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] else {
            return nil
        }
        return iconFiles.last
    }
}
