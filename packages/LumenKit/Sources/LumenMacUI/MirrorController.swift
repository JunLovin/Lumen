#if os(macOS)
    import AppKit
    import LumenApplication
    import LumenDomain
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
        private var ghost: GhostOverlay?
        private var timing = DragTiming()
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
            ghost?.setTuning(tuning)
            [leftGlow, rightGlow].forEach { $0?.setTuning(tuning) }
        }

        func direct(_ offer: TransferOffer) {
            shelf.addDirect(offer, edge: lastEdge)
            prepare()
            show()
            ghost?.playSweep(fromLeft: lastEdge == .right)
            hide()
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
            ghost?.setPalette(newStart.palette)
            leftGlow?.setPalette(newStart.palette)
            rightGlow?.setPalette(newStart.palette)
            guard !newStart.thumbnailJPEG.isEmpty else { return }
            ghost?.setThumbnail(newStart.thumbnailJPEG)
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
            timing.lastFrameNs = receivedAtNs
            let glow = frame.sample.edge == .right ? leftGlow : rightGlow
            glow?.show()
            glow?.setProximity(frame.sample.edgeProximity)
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
            timing.logRelease(atNanoseconds: clock.nowNanoseconds())
            ghost?.playSweep(fromLeft: lastEdge == .right)
            landing = GhostOverlay.landing(from: pose, end: end, edge: lastEdge, shelf: shelf, tuning: tuning)
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
            timing.logLanding(atNanoseconds: clock.nowNanoseconds())
            hide()
            if let start {
                shelf.add(jpeg: start.thumbnailJPEG, edge: lastEdge, session: start.session)
                reportLanded(start.session)
                if settings.isSoundEnabled {
                    sound.play(edge: lastEdge)
                }
            }
        }

        private func show() {
            ghost?.show()
            if settings.isLensEnabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                lens.start()
            }
        }

        private func hide() {
            ghost?.hide { [weak self] in self?.lens.stop() }
            interpolator.reset()
            lastPose = nil
        }

        private func prepare() {
            guard ghost == nil else { return }
            ghost = GhostOverlay(
                nextPose: { [weak self] in self?.nextPose() },
                lensSurface: { [weak self] in self?.lens.latestSurface },
                tuning: tuning
            )
            leftGlow = EdgeOverlayPanel(onLeftEdge: true) { _ in }
            rightGlow = EdgeOverlayPanel { _ in }
            [leftGlow, rightGlow].forEach { $0?.setTuning(tuning) }
        }
    }
#endif
