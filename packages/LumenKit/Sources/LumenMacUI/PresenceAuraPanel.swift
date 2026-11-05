#if os(macOS)
    import AppKit
    import LumenDomain
    import QuartzCore

    /// A Core Animation layer breathes without waking the app, unlike the shader overlay.
    @MainActor
    final class PresenceAuraPanel {
        private static let breathKey = "breath"
        private let panel: NSPanel
        private let line = CALayer()
        private var isLifted = false

        init() {
            panel = NSPanel(
                contentRect: .zero,
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
            let token = DesignTokens.Glow.primary
            line.backgroundColor = CGColor(
                red: CGFloat(token.red),
                green: CGFloat(token.green),
                blue: CGFloat(token.blue),
                alpha: 1
            )
            let view = NSView()
            view.wantsLayer = true
            view.layer = line
            panel.contentView = view
        }

        func update(placement: Placement?, isConnected: Bool) {
            guard
                isConnected,
                let placement,
                placement.confidence >= DesignTokens.Presence.minConfidence,
                placement.side == .left || placement.side == .right
            else {
                panel.orderOut(nil)
                return
            }
            let screen = BuiltInScreen.current.frame
            let width = DesignTokens.Presence.macWidthPoints
            panel.setFrame(
                NSRect(
                    x: placement.side == .left ? screen.minX : screen.maxX - width,
                    y: screen.minY,
                    width: width,
                    height: screen.height
                ),
                display: false
            )
            panel.orderFrontRegardless()
            applyBreath()
        }

        func setLifted(_ lifted: Bool) {
            isLifted = lifted
            applyBreath()
        }

        private func applyBreath() {
            line.removeAnimation(forKey: Self.breathKey)
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            guard !isLifted, !reduceMotion else {
                line.opacity = isLifted ? DesignTokens.Presence.liftOpacity : DesignTokens.Presence.restOpacity
                return
            }
            line.opacity = DesignTokens.Presence.restOpacity
            let breath = CABasicAnimation(keyPath: "opacity")
            breath.fromValue = DesignTokens.Presence.restOpacity
            breath.toValue = DesignTokens.Presence.peakOpacity
            breath.duration = DesignTokens.Motion.glowBreathSeconds / 2
            breath.autoreverses = true
            breath.repeatCount = .infinity
            breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            line.add(breath, forKey: Self.breathKey)
        }
    }
#endif
