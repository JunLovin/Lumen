#if os(macOS)
    import LumenApplication
    import LumenDomain
    import Observation

    public struct LatencySummary: Equatable {
        public let p50: Double
        public let p95: Double
        public let count: Int

        init?(window: SampleWindow) {
            guard let p50 = window.percentile(0.5), let p95 = window.percentile(0.95) else { return nil }
            self.p50 = p50
            self.p95 = p95
            count = window.count
        }
    }

    @MainActor
    @Observable
    public final class LabModel {
        private static let statsPublishIntervalNs: UInt64 = 500_000_000
        private static let windowCapacity = 2048

        public private(set) var isListening = false
        public private(set) var isConnected = false
        public private(set) var clockRoundTripMilliseconds: Double?
        public private(set) var latestFrame: DragFrameSample?
        public private(set) var networkLatency: LatencySummary?
        public private(set) var renderLatency: LatencySummary?
        public private(set) var receivedFrames = 0
        public private(set) var lostFrames = 0
        public private(set) var acousticReading: AcousticReading?
        public private(set) var gpuTime: LatencySummary?
        public private(set) var isOverlayVisible = false
        public var manualProximity: Float = 0 {
            didSet { pushProximity() }
        }

        public var chirpAmplitude: Float {
            didSet {
                let amplitude = chirpAmplitude
                let session = session
                Task { await session.setChirpAmplitude(amplitude) }
            }
        }

        @ObservationIgnored private let session: PeerLabSession
        @ObservationIgnored private let clock: any ClockPort
        @ObservationIgnored private var networkWindow = SampleWindow(capacity: windowCapacity)
        @ObservationIgnored private var renderWindow = SampleWindow(capacity: windowCapacity)
        @ObservationIgnored private var gpuWindow = SampleWindow(capacity: windowCapacity)
        @ObservationIgnored private var overlay: EdgeOverlayPanel?
        @ObservationIgnored private var firstSequence: UInt32?
        @ObservationIgnored private var currentSession: UInt32?
        @ObservationIgnored private var pendingFrame: LocalizedDragFrame?
        @ObservationIgnored private var lastPublishNs: UInt64 = 0

        public init(session: PeerLabSession, clock: any ClockPort, chirpAmplitude: Float) {
            self.session = session
            self.clock = clock
            self.chirpAmplitude = chirpAmplitude
        }

        public func setListening(_ isListening: Bool) {
            self.isListening = isListening
        }

        public func consumeUpdates() async {
            for await update in session.updates {
                apply(update)
            }
        }

        public func renderTick() {
            guard let frame = pendingFrame, let timestamp = frame.localTimestampNs else { return }
            pendingFrame = nil
            renderWindow.add(Self.milliseconds(from: timestamp, to: clock.nowNanoseconds()))
        }

        public func resetStats() {
            networkWindow = SampleWindow(capacity: Self.windowCapacity)
            renderWindow = SampleWindow(capacity: Self.windowCapacity)
            gpuWindow = SampleWindow(capacity: Self.windowCapacity)
            receivedFrames = 0
            lostFrames = 0
            firstSequence = nil
            networkLatency = nil
            renderLatency = nil
            gpuTime = nil
        }

        public func toggleOverlay() {
            if isOverlayVisible {
                overlay?.hide()
                isOverlayVisible = false
                return
            }
            if overlay == nil {
                overlay = EdgeOverlayPanel { [weak self] milliseconds in
                    Task { @MainActor in self?.recordGPUTime(milliseconds) }
                }
            }
            overlay?.show()
            isOverlayVisible = overlay != nil
            pushProximity()
        }

        private func recordGPUTime(_ milliseconds: Double) {
            gpuWindow.add(milliseconds)
            let now = clock.nowNanoseconds()
            if now - lastPublishNs > Self.statsPublishIntervalNs {
                publishStats(at: now)
            }
        }

        private func apply(_ update: PeerLabUpdate) {
            switch update {
            case let .connection(isConnected):
                self.isConnected = isConnected
            case let .clockRoundTrip(milliseconds):
                clockRoundTripMilliseconds = milliseconds
            case let .frame(frame, receivedAtNs):
                apply(frame, receivedAtNs: receivedAtNs)
            case let .acousticReport(reading):
                acousticReading = reading
            }
        }

        private func apply(_ frame: LocalizedDragFrame, receivedAtNs: UInt64) {
            let sample = frame.sample
            if currentSession != sample.session {
                currentSession = sample.session
                firstSequence = nil
                receivedFrames = 0
            }
            let first = firstSequence ?? sample.sequence
            firstSequence = first
            receivedFrames += 1
            lostFrames = max(0, Int(sample.sequence) - Int(first) + 1 - receivedFrames)
            latestFrame = sample
            pendingFrame = frame
            pushProximity()
            if let timestamp = frame.localTimestampNs {
                networkWindow.add(Self.milliseconds(from: timestamp, to: receivedAtNs))
            }
            if receivedAtNs - lastPublishNs > Self.statsPublishIntervalNs {
                publishStats(at: receivedAtNs)
            }
        }

        private func publishStats(at now: UInt64) {
            lastPublishNs = now
            networkLatency = LatencySummary(window: networkWindow)
            renderLatency = LatencySummary(window: renderWindow)
            gpuTime = LatencySummary(window: gpuWindow)
        }

        private func pushProximity() {
            overlay?.setProximity(max(manualProximity, latestFrame?.edgeProximity ?? 0))
        }

        private static func milliseconds(from start: UInt64, to end: UInt64) -> Double {
            Double(Int64(truncatingIfNeeded: end) - Int64(truncatingIfNeeded: start)) / 1_000_000
        }
    }
#endif
