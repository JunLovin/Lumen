#if os(macOS)
    import AppKit
    import SwiftUI

    /// A release travels over TCP next to the file; these numbers show when that delays it.
    struct DragTiming {
        private static let nanosecondsPerMillisecond: UInt64 = 1_000_000
        var lastFrameNs: UInt64 = 0
        private var releaseNs: UInt64 = 0

        mutating func logRelease(atNanoseconds now: UInt64) {
            releaseNs = now
            let lag = (now &- lastFrameNs) / Self.nanosecondsPerMillisecond
            dropLog.notice("Release arrived \(lag) ms after the last frame")
        }

        func logLanding(atNanoseconds now: UInt64) {
            let duration = (now &- releaseNs) / Self.nanosecondsPerMillisecond
            dropLog.notice("Landed \(duration) ms after the release")
        }
    }

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
