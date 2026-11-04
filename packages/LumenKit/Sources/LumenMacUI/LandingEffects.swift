#if os(macOS)
    import AppKit
    import SwiftUI

    struct LandingWave: View {
        @State private var hasPlayed = false

        var body: some View {
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white, lineWidth: 2)
                    .scaleEffect(hasPlayed ? DesignTokens.Landing.waveScale : 0.9)
                    .opacity(hasPlayed ? 0 : 0.8)
                    .onAppear {
                        withAnimation(.spring(duration: DesignTokens.Landing.waveSeconds)) { hasPlayed = true }
                    }
            }
        }
    }

    struct DeliveredSheen: View {
        @State private var offset = -1.2

        var body: some View {
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                GeometryReader { geometry in
                    LinearGradient(colors: [.clear, .white.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
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
