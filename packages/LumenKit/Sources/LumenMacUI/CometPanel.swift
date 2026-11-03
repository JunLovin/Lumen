#if os(macOS)
    import AppKit
    import LumenDomain
    import SwiftUI

    @MainActor
    final class CometPanel {
        private let panel: NSPanel
        private var dismissal: Task<Void, Never>?

        init?() {
            let screen = BuiltInScreen.current
            panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        }

        func play(from origin: PlacementSide, to target: PlacementSide) {
            panel.contentView = NSHostingView(rootView: CometView(origin: origin, target: target, startedAt: .now))
            panel.orderFrontRegardless()
            dismissal?.cancel()
            dismissal = Task { [panel] in
                try? await Task.sleep(for: .seconds(DesignTokens.Placement.cometSeconds))
                if !Task.isCancelled {
                    panel.orderOut(nil)
                }
            }
        }
    }

    private struct CometView: View {
        let origin: PlacementSide
        let target: PlacementSide
        let startedAt: Date
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            TimelineView(.animation) { context in
                Canvas { graphics, size in
                    let progress = min(
                        context.date.timeIntervalSince(startedAt) / DesignTokens.Placement.cometSeconds,
                        1
                    )
                    draw(in: &graphics, size: size, progress: reduceMotion ? 1 : progress)
                }
            }
        }

        private func draw(in graphics: inout GraphicsContext, size: CGSize, progress: Double) {
            let token = DesignTokens.Glow.primary
            let color = Color(red: Double(token.red), green: Double(token.green), blue: Double(token.blue))
            let start = Self.perimeterPosition(of: origin)
            let end = Self.perimeterPosition(of: target)
            let head = start + (end - start) * progress
            let tail = head - DesignTokens.Placement.cometLengthFraction * (end > start ? 1 : -1)
            var path = Path()
            let steps = 24
            for step in 0 ... steps {
                let position = tail + (head - tail) * Double(step) / Double(steps)
                let point = Self.point(at: position, in: size)
                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            graphics.addFilter(.blur(radius: DesignTokens.Placement.cometWidthPoints))
            graphics.stroke(
                path,
                with: .color(color.opacity(1 - max(progress - 0.8, 0) * 5)),
                lineWidth: DesignTokens.Placement.cometWidthPoints
            )
        }

        private static func perimeterPosition(of side: PlacementSide) -> Double {
            switch side {
            case .above: 0.125
            case .right: 0.375
            case .below: 0.625
            case .left, .unknown: 0.875
            }
        }

        private static func point(at position: Double, in size: CGSize) -> CGPoint {
            let wrapped = (position.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
            let segment = wrapped * 4
            let fraction = segment.truncatingRemainder(dividingBy: 1)
            switch Int(segment) {
            case 0: return CGPoint(x: size.width * fraction, y: 0)
            case 1: return CGPoint(x: size.width, y: size.height * fraction)
            case 2: return CGPoint(x: size.width * (1 - fraction), y: size.height)
            default: return CGPoint(x: 0, y: size.height * (1 - fraction))
            }
        }
    }
#endif
