import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.35

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let availableWidth = geo.size.width.isFinite ? max(geo.size.width, 0) : 0
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.2), location: 0.5),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: availableWidth * 0.5)
                        .offset(x: phase * availableWidth)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
