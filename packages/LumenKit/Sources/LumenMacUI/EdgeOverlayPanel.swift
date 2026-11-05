#if os(macOS)
    import AppKit
    import MetalKit

    @MainActor
    final class EdgeOverlayPanel {
        private let panel: NSPanel
        private let renderer: EdgeGlowRenderer
        private let metalView: MTKView

        init?(onGPUTime: @escaping @Sendable (Double) -> Void) {
            guard
                let screen = NSScreen.main,
                let device = MTLCreateSystemDefaultDevice()
            else { return nil }
            let width = DesignTokens.Glow.overlayWidthPoints
            let frame = NSRect(
                x: screen.frame.maxX - width,
                y: screen.frame.minY,
                width: width,
                height: screen.frame.height
            )
            let metalView = MTKView(frame: NSRect(origin: .zero, size: frame.size), device: device)
            metalView.colorPixelFormat = .bgra8Unorm
            metalView.clearColor = MTLClearColorMake(0, 0, 0, 0)
            metalView.layer?.isOpaque = false
            guard let renderer = EdgeGlowRenderer(
                device: device,
                pixelFormat: metalView.colorPixelFormat,
                onGPUTime: onGPUTime
            ) else { return nil }
            metalView.delegate = renderer

            let panel = NSPanel(
                contentRect: frame,
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
            panel.contentView = metalView

            self.panel = panel
            self.renderer = renderer
            self.metalView = metalView
        }

        func show() {
            panel.orderFrontRegardless()
        }

        func hide() {
            panel.orderOut(nil)
        }

        func setProximity(_ proximity: Float) {
            renderer.proximity = proximity
        }
    }
#endif
