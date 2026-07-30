import SwiftUI

/// Adds a self-dismissing glass toast overlay to a view.
extension View {
    func glassToast(
        message: String?,
        systemImage: String,
        bottomPadding: CGFloat
    ) -> some View {
        modifier(
            GlassToastModifier(
                message: message,
                systemImage: systemImage,
                bottomPadding: bottomPadding
            )
        )
    }
}

private struct GlassToastModifier: ViewModifier {
    let message: String?
    let systemImage: String
    let bottomPadding: CGFloat

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                HStack(spacing: 9) {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                    Text(message)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 9)
                .padding(.horizontal, 24)
                .padding(.bottom, bottomPadding)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.72, anchor: .bottom)
                            .combined(with: .move(edge: .bottom))
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.86, anchor: .bottom)
                            .combined(with: .opacity)
                    )
                )
                .allowsHitTesting(false)
            }
        }
        .animation(
            .interpolatingSpring(mass: 0.82, stiffness: 210, damping: 18, initialVelocity: 0.28),
            value: message
        )
    }
}
