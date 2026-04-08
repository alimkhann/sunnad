import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: max(0, phase - 0.2)),
                        .init(color: .white.opacity(0.2), location: phase),
                        .init(color: .clear, location: min(1, phase + 0.2))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .mask(content)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
