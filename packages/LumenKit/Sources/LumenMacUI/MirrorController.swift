#if os(macOS)
    import AppKit
    import LumenApplication
    import LumenDomain
    import MetalKit
    import QuartzCore

    @MainActor
    final class MirrorController {
        private static let nanosecondsPerMillisecond: UInt64 = 1_000_000
        private let clock: any ClockPort
        private let reportLanded: (UInt32) -> Void
        private let shelf: ShelfPanel
        private let comet = CometPanel()
        private let finderDrag: FinderDragMonitor
        private let presence = PresenceAuraPanel()
        private let settings: EffectSettings
        private let sound = LandingSound()
        private let lens = LensCapture()
        private var tuning = MotionTuning()
        private var glowHideTask: Task<Void, Never>?
        private var panel: NSPanel?
        private var metalView: MTKView?
        private var renderer: GhostRenderer?
        private var leftGlow: EdgeOverlayPanel?
        private var rightGlow: EdgeOverlayPanel?
        private var interpolator = FrameInterpolator(
            maximumExtrapolationNanoseconds: DesignTokens.Mirror
                .maxExtrapolationMilliseconds * nanosecondsPerMillisecond
        )
        private var start: DragStart?
        private var currentSession: UInt32 = 0
        private var lastPose: GhostPose?
        private var lastEdge: PhoneEdge = .right
        private var landing: GhostLanding?
        private var lastTickTime = CACurrentMediaTime()

        init(
            clock: any ClockPort,
            destination: DestinationFolder,
            settings: EffectSettings,
            reportLanded: @escaping (UInt32) -> Void,
            sendFiles: @escaping ([String]) -> Void
        ) {
            self.settings = settings
            shelf = ShelfPanel(destination: destination)
            finderDrag = FinderDragMonitor(onDrop: sendFiles)
            self.clock = clock
            self.reportLanded = reportLanded
        }

        func tune(name: String, value: Float) {
            tuning.set(name: name, value: value)
            renderer?.tuning = tuning
            leftGlow?.setTuning(tuning)
            rightGlow?.setTuning(tuning)
        }

        func direct(_ offer: TransferOffer) {
            shelf.addDirect(offer, edge: lastEdge)
        }

        func placementChanged(from previous: PlacementSide?, to current: PlacementSide) {
            finderDrag.placement = current
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            if let previous, previous != current, current != .unknown, !reduceMotion {
                comet?.play(from: previous, to: current)
            }
        }

        func presenceChanged(_ placement: Placement?, isConnected: Bool) {
            presence.update(placement: placement, isConnected: isConnected)
        }

        func transfer(_ update: TransferUpdate) {
            shelf.update(update)
        }

        func begin(_ newStart: DragStart) {
            start = newStart
            prepare()
            presence.setLifted(true)
            glowHideTask?.cancel()
            renderer?.palette = newStart.palette
            leftGlow?.setPalette(newStart.palette)
            rightGlow?.setPalette(newStart.palette)
            guard !newStart.thumbnailJPEG.isEmpty else { return }
            renderer?.texture = (metalView?.device).flatMap { device in
                try? MTKTextureLoader(device: device).newTexture(
                    data: Data(newStart.thumbnailJPEG),
                    options: [.origin: MTKTextureLoader.Origin.topLeft, .SRGB: false]
                )
            }
        }

        func add(_ frame: LocalizedDragFrame, receivedAtNs: UInt64) {
            guard start?.session == frame.sample.session else { return }
            if frame.sample.session != currentSession {
                currentSession = frame.sample.session
                interpolator.reset()
                landing = nil
                prepare()
                show()
            }
            interpolator.add(TimedDragFrame(
                sample: frame.sample,
                localTimestampNs: frame.localTimestampNs ?? receivedAtNs
            ))
            lastEdge = frame.sample.edge
            glow(for: frame.sample.edge)?.show()
            glow(for: frame.sample.edge)?.setProximity(frame.sample.edgeProximity)
        }

        func end(_ end: DragEnd) {
            presence.setLifted(false)
            leftGlow?.setProximity(0)
            rightGlow?.setProximity(0)
            glowHideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(DesignTokens.Landing.glowFadeSeconds))
                guard !Task.isCancelled else { return }
                self?.leftGlow?.hide()
                self?.rightGlow?.hide()
            }
            guard end.crossed, let pose = lastPose else {
                hide()
                return
            }
            let space = BuiltInScreen.space
            let sign = space.depthSign(edge: lastEdge)
            let perMillimeter = space.pointsPerMillimeter
            landing = GhostLanding(
                from: pose,
                velocity: MacPoint(
                    x: Double(end.velocityXMillimetersPerSecond) * perMillimeter * sign,
                    y: Double(end.velocityYMillimetersPerSecond) * perMillimeter
                ),
                target: shelf.slot(forEdge: lastEdge, in: space, objectSize: pose.size),
                parameters: SpringParameters(
                    response: tuning.landResponse,
                    damping: tuning.landDamping
                )
            )
            lastTickTime = CACurrentMediaTime()
        }

        private func nextPose() -> GhostPose? {
            if landing != nil {
                return advanceLanding()
            }
            let delay = DesignTokens.Mirror.renderDelayMilliseconds * Self.nanosecondsPerMillisecond
            guard
                let frame = interpolator.frame(atNanoseconds: clock.nowNanoseconds() - delay)
            else { return nil }
            let height = Double(start?.phoneHeightMillimeters ?? 0)
            let pose = BuiltInScreen.space.ghostPose(for: frame, phoneHeightMillimeters: height)
            lastPose = pose
            return pose
        }

        private func advanceLanding() -> GhostPose? {
            guard var current = landing else { return nil }
            let now = CACurrentMediaTime()
            let pose = current.advance(seconds: now - lastTickTime)
            lastTickTime = now
            landing = current
            if current.isSettled {
                finishLanding()
            }
            return pose
        }

        private func finishLanding() {
            landing = nil
            hide()
            if let start {
                shelf.add(jpeg: start.thumbnailJPEG, edge: lastEdge, session: start.session)
                reportLanded(start.session)
                if settings.isSoundEnabled {
                    sound.play(edge: lastEdge)
                }
            }
        }

        private func glow(for edge: PhoneEdge) -> EdgeOverlayPanel? {
            edge == .right ? leftGlow : rightGlow
        }

        private func show() {
            panel?.orderFrontRegardless()
            metalView?.isPaused = false
            if settings.isLensEnabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                lens.start()
            }
        }

        private func hide() {
            panel?.orderOut(nil)
            metalView?.isPaused = true
            lens.stop()
            renderer?.texture = nil
            lastPose = nil
        }

        private func prepare() {
            guard panel == nil, let device = MTLCreateSystemDefaultDevice() else { return }
            let frame = BuiltInScreen.current.frame
            let view = MTKView(frame: NSRect(origin: .zero, size: frame.size), device: device)
            view.colorPixelFormat = .bgra8Unorm
            view.clearColor = MTLClearColorMake(0, 0, 0, 0)
            view.layer?.isOpaque = false
            view.isPaused = true
            guard let renderer = GhostRenderer(device: device, pixelFormat: view.colorPixelFormat) else { return }
            renderer.nextPose = { [weak self] in self?.nextPose() }
            renderer.lensSurface = { [weak self] in self?.lens.latestSurface }
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
            metalView = view
            self.renderer = renderer
            leftGlow = EdgeOverlayPanel(onLeftEdge: true) { _ in }
            rightGlow = EdgeOverlayPanel { _ in }
            leftGlow?.setTuning(tuning)
            rightGlow?.setTuning(tuning)
        }
    }
#endif
