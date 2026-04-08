import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var startPoint: UnitPoint = .init(x: -1, y: 0.5)
    @State private var endPoint: UnitPoint = .init(x: 0, y: 0.5)

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ],
                    startPoint: startPoint,
                    endPoint: endPoint
                )
                .mask(content)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    startPoint = .init(x: 1, y: 0.5)
                    endPoint = .init(x: 2, y: 0.5)
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
