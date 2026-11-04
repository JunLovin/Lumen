#if os(macOS)
    import AppKit
    import SwiftUI

    struct LandingPop: ViewModifier {
        @State private var scale = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? 1
            : DesignTokens.Landing.popScale

        func body(content: Content) -> some View {
            content
                .scaleEffect(scale)
                .onAppear {
                    let spring = DesignTokens.Motion.land
                    withAnimation(.spring(response: spring.response, dampingFraction: spring.damping)) { scale = 1 }
                }
        }
    }

    struct DeliveredSheen: View {
        @State private var offset = -1.2

        var body: some View {
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.7), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width / 2)
                    .rotationEffect(.degrees(20))
                    .offset(x: geometry.size.width * offset)
                }
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.spring(duration: DesignTokens.Landing.sheenSeconds)) { offset = 1.4 }
                }
            }
        }
    }
#endif
