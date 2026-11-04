#if os(macOS)
    import AppKit
    import IOSurface
    import LumenDomain
    import MetalKit

    @MainActor
    final class GhostOverlay {
        private let panel: NSPanel
        private let view: MTKView
        private let renderer: GhostRenderer

        init?(
            nextPose: @escaping () -> GhostPose?,
            lensSurface: @escaping () -> IOSurfaceRef?,
            tuning: MotionTuning
        ) {
            guard let device = MTLCreateSystemDefaultDevice() else { return nil }
            let frame = BuiltInScreen.current.frame
            let view = MTKView(frame: NSRect(origin: .zero, size: frame.size), device: device)
            view.colorPixelFormat = .bgra8Unorm
            view.clearColor = MTLClearColorMake(0, 0, 0, 0)
            view.layer?.isOpaque = false
            view.isPaused = true
            guard let renderer = GhostRenderer(device: device, pixelFormat: view.colorPixelFormat) else { return nil }
            renderer.nextPose = nextPose
            renderer.lensSurface = lensSurface
            renderer.tuning = tuning
            view.delegate = renderer
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
            panel.contentView = view
            self.panel = panel
            self.view = view
            self.renderer = renderer
        }

        static func landing(
            from pose: GhostPose,
            end: DragEnd,
            edge: PhoneEdge,
            shelf: ShelfPanel,
            tuning: MotionTuning
        ) -> GhostLanding {
            let space = BuiltInScreen.space
            let sign = space.depthSign(edge: edge)
            let perMillimeter = space.pointsPerMillimeter
            return GhostLanding(
                from: pose,
                velocity: MacPoint(
                    x: Double(end.velocityXMillimetersPerSecond) * perMillimeter * sign,
                    y: Double(end.velocityYMillimetersPerSecond) * perMillimeter
                ),
                target: shelf.slot(forEdge: edge, in: space, objectSize: pose.size),
                parameters: SpringParameters(response: tuning.landResponse, damping: tuning.landDamping)
            )
        }

        func playSweep(fromLeft: Bool) {
            renderer.playSweep(fromLeft: fromLeft)
        }

        func setTuning(_ tuning: MotionTuning) {
            renderer.tuning = tuning
        }

        func setPalette(_ palette: GlowPalette?) {
            renderer.palette = palette
        }

        func setThumbnail(_ jpeg: [UInt8]) {
            renderer.texture = view.device.flatMap { device in
                try? MTKTextureLoader(device: device).newTexture(
                    data: Data(jpeg),
                    options: [.origin: MTKTextureLoader.Origin.topLeft, .SRGB: false]
                )
            }
        }

        func show() {
            renderer.onSweepFinished = nil
            panel.orderFrontRegardless()
            view.isPaused = false
        }

        /// A sweep in flight finishes before the panel goes away.
        func hide(onHidden: @escaping () -> Void) {
            guard !renderer.isSweeping else {
                renderer.onSweepFinished = { [weak self] in self?.hide(onHidden: onHidden) }
                return
            }
            onHidden()
            panel.orderOut(nil)
            view.isPaused = true
            renderer.texture = nil
        }
    }
#endif
