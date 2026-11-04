#if os(macOS)
    import LumenApplication
    import LumenDomain
    import Observation

    @MainActor
    @Observable
    public final class LabModel {
        static let statsPublishIntervalNs: UInt64 = 500_000_000
        private static let windowCapacity = 2048
        private static let historyLength = 8

        public private(set) var isListening = false
        public private(set) var isConnected = false
        public private(set) var clockRoundTripMilliseconds: Double?
        public private(set) var latestFrame: DragFrameSample?
        public private(set) var networkLatency: LatencySummary?
        public private(set) var renderLatency: LatencySummary?
        public private(set) var frameGap: LatencySummary?
        public private(set) var receivedFrames = 0
        public private(set) var lostFrames = 0
        public private(set) var acousticReading: AcousticReading?
        public private(set) var gpuTime: LatencySummary?
        public internal(set) var isOverlayVisible = false
        public private(set) var placement: Placement?
        public private(set) var placementHistory: [String] = []
        public private(set) var canPlayUltrasound: Bool?
        public private(set) var lastFileHash: String?
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
        @ObservationIgnored let clock: any ClockPort
        @ObservationIgnored private let mirror: MirrorController
        @ObservationIgnored private var networkWindow = SampleWindow(capacity: windowCapacity)
        @ObservationIgnored private var renderWindow = SampleWindow(capacity: windowCapacity)
        @ObservationIgnored var gpuWindow = SampleWindow(capacity: windowCapacity)
        @ObservationIgnored var overlay: EdgeOverlayPanel?
        @ObservationIgnored private var firstSequence: UInt32?
        @ObservationIgnored private var currentSession: UInt32?
        @ObservationIgnored private var gapWindow = SampleWindow(capacity: windowCapacity)
        @ObservationIgnored private var lastArrivalNs: UInt64?
        @ObservationIgnored private var pendingFrames: [LocalizedDragFrame] = []
        @ObservationIgnored var lastPublishNs: UInt64 = 0

        public init(
            session: PeerLabSession,
            clock: any ClockPort,
            destination: DestinationFolder,
            chirpAmplitude: Float
        ) {
            self.session = session
            self.clock = clock
            mirror = MirrorController(clock: clock, destination: destination) { landed in
                Task { await session.reportLanded(session: landed) }
            } sendFiles: { paths in
                Task { await session.sendFiles(paths: paths) }
            }
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
            guard !pendingFrames.isEmpty else { return }
            let now = clock.nowNanoseconds()
            for timestamp in pendingFrames.compactMap(\.localTimestampNs) {
                renderWindow.add(Self.milliseconds(from: timestamp, to: now))
            }
            pendingFrames.removeAll(keepingCapacity: true)
        }

        public func resetStats() {
            networkWindow = SampleWindow(capacity: Self.windowCapacity)
            renderWindow = SampleWindow(capacity: Self.windowCapacity)
            gapWindow = SampleWindow(capacity: Self.windowCapacity)
            lastArrivalNs = nil
            frameGap = nil
            gpuWindow = SampleWindow(capacity: Self.windowCapacity)
            receivedFrames = 0
            lostFrames = 0
            firstSequence = nil
            networkLatency = nil
            renderLatency = nil
            gpuTime = nil
        }

        public func playTestTone(on channel: AudioChannel) {
            let session = session
            Task { await session.playTestTone(on: channel) }
        }

        private func apply(_ update: PeerLabUpdate) {
            switch update {
            case let .connection(isConnected):
                self.isConnected = isConnected
            case let .bestClockRoundTrip(milliseconds):
                clockRoundTripMilliseconds = milliseconds
            case let .frame(frame, receivedAtNs):
                apply(frame, receivedAtNs: receivedAtNs)
            case let .acousticReport(reading):
                acousticReading = reading
            case let .placement(placement, evidence):
                apply(placement, evidence: evidence)
            case let .audioRoute(canPlayUltrasound):
                self.canPlayUltrasound = canPlayUltrasound
            case let .dragBegan(start):
                mirror.begin(start)
            case let .dragEnded(end):
                mirror.end(end)
            case let .directTransfer(offer):
                mirror.direct(offer)
            case .sendingFiles:
                break
            case let .transfer(update):
                mirror.transfer(update)
                if case let .completed(_, sha256Hex) = update.stage {
                    lastFileHash = sha256Hex
                }
            }
        }

        private func apply(_ newPlacement: Placement, evidence: String) {
            mirror.placementChanged(from: placement?.side, to: newPlacement.side)
            placement = newPlacement
            placementHistory = Array(([evidence] + placementHistory).prefix(Self.historyLength))
        }

        private func apply(_ frame: LocalizedDragFrame, receivedAtNs: UInt64) {
            let sample = frame.sample
            if currentSession != sample.session {
                currentSession = sample.session
                firstSequence = nil
                receivedFrames = 0
                lastArrivalNs = nil
            }
            if let lastArrivalNs {
                gapWindow.add(Self.milliseconds(from: lastArrivalNs, to: receivedAtNs))
            }
            lastArrivalNs = receivedAtNs
            let first = firstSequence ?? sample.sequence
            firstSequence = first
            receivedFrames += 1
            lostFrames = max(0, Int(sample.sequence) - Int(first) + 1 - receivedFrames)
            latestFrame = sample
            pendingFrames.append(frame)
            mirror.add(frame, receivedAtNs: receivedAtNs)
            pushProximity()
            if let timestamp = frame.localTimestampNs {
                networkWindow.add(Self.milliseconds(from: timestamp, to: receivedAtNs))
            }
            if receivedAtNs - lastPublishNs > Self.statsPublishIntervalNs {
                publishStats(at: receivedAtNs)
            }
        }

        func publishStats(at now: UInt64) {
            lastPublishNs = now
            networkLatency = LatencySummary(window: networkWindow)
            renderLatency = LatencySummary(window: renderWindow)
            frameGap = LatencySummary(window: gapWindow)
            gpuTime = LatencySummary(window: gpuWindow)
        }

        func pushProximity() {
            overlay?.setProximity(max(manualProximity, latestFrame?.edgeProximity ?? 0))
        }

        private static func milliseconds(from start: UInt64, to end: UInt64) -> Double {
            Double(Int64(truncatingIfNeeded: end) - Int64(truncatingIfNeeded: start)) / 1_000_000
        }
    }
#endif
