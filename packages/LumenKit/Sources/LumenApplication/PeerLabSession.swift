import LumenDomain

public struct LocalizedDragFrame: Sendable, Equatable {
    public let sample: DragFrameSample
    public let localTimestampNs: UInt64?
}

public enum PeerLabUpdate: Sendable, Equatable {
    case connection(isConnected: Bool)
    case bestClockRoundTrip(milliseconds: Double)
    case frame(LocalizedDragFrame, receivedAtNs: UInt64)
    case acousticReport(AcousticReading)
    case placement(Placement, evidence: String)
    case audioRoute(canPlayUltrasound: Bool)
    case dragBegan(DragStart)
    case dragEnded(DragEnd)
}

public actor PeerLabSession {
    private static let burstPingCount = 8
    private static let burstPingInterval = Duration.milliseconds(100)
    private static let steadyPingInterval = Duration.seconds(10)

    public nonisolated let updates: AsyncStream<PeerLabUpdate>
    private let updatesContinuation: AsyncStream<PeerLabUpdate>.Continuation
    private let link: any PeerLinkPort
    private let clock: any ClockPort
    private let chirpPlayer: any ChirpPlayerPort
    private let audioRoute: any AudioRoutePort
    private let placementStore: any PlacementStorePort
    private var resolver = PlacementResolver()
    private var detachment = DetachmentDetector(farRSSI: -75, nearRSSI: -65, requiredReadings: 5)
    private var estimator = ClockOffsetEstimator()
    private var chirpAmplitude: Float
    private var pingTask: Task<Void, Never>?

    public init(
        link: any PeerLinkPort,
        clock: any ClockPort,
        chirpPlayer: any ChirpPlayerPort,
        audioRoute: any AudioRoutePort,
        placementStore: any PlacementStorePort,
        chirpAmplitude: Float
    ) {
        (updates, updatesContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(256))
        self.link = link
        self.clock = clock
        self.chirpPlayer = chirpPlayer
        self.audioRoute = audioRoute
        self.placementStore = placementStore
        self.chirpAmplitude = chirpAmplitude
    }

    public func run() async {
        if let saved = await placementStore.load() {
            resolver = PlacementResolver(distribution: saved, atNanoseconds: clock.nowNanoseconds())
        }
        for await event in link.events {
            await handle(event)
        }
    }

    public func setChirpAmplitude(_ amplitude: Float) {
        chirpAmplitude = amplitude
    }

    public func reportLanded(session: UInt32) async {
        await link.send(.landed(session: session))
    }

    public func playTestTone(on channel: AudioChannel) async {
        await chirpPlayer.playTestTone(on: channel)
    }

    func handle(_ event: PeerEvent) async {
        switch event {
        case .connected:
            updatesContinuation.yield(.connection(isConnected: true))
            estimator = ClockOffsetEstimator()
            startPinging()
            await publishPlacement(evidence: "connected")
            await beginLocateIfPossible()
        case .disconnected, .incompatible:
            updatesContinuation.yield(.connection(isConnected: false))
            pingTask?.cancel()
        case let .received(message):
            await handle(message)
        }
    }

    private func handle(_ message: PeerMessage) async {
        switch message {
        case let .clockPong(originNs, receiveNs, transmitNs):
            let sample = ClockSample(
                originNs: originNs,
                remoteReceiveNs: receiveNs,
                remoteTransmitNs: transmitNs,
                destinationNs: clock.nowNanoseconds()
            )
            estimator.add(sample)
            let best = estimator.bestSample?.roundTripNanoseconds ?? sample.roundTripNanoseconds
            updatesContinuation.yield(.bestClockRoundTrip(milliseconds: Double(best) / 1_000_000))
        case let .clockPing(originNs):
            let now = clock.nowNanoseconds()
            await link.send(.clockPong(originNs: originNs, receiveNs: now, transmitNs: now))
        case let .dragFrame(sample):
            let frame = LocalizedDragFrame(
                sample: sample,
                localTimestampNs: estimator.localTimestamp(fromRemote: sample.timestampNs)
            )
            updatesContinuation.yield(.frame(frame, receivedAtNs: clock.nowNanoseconds()))
        case .playChirpPair:
            if await audioRoute.canPlayUltrasound() {
                await chirpPlayer.playPair(amplitude: chirpAmplitude)
            }
        case let .acousticReport(reading):
            updatesContinuation.yield(.acousticReport(reading))
            resolver.apply(
                .acoustic(
                    tauMicroseconds: reading.tauMicroseconds,
                    levelDifferenceDecibels: reading.levelDifferenceDecibels,
                    snrDecibels: reading.snrDecibels
                ),
                atNanoseconds: clock.nowNanoseconds()
            )
            await publishPlacement(evidence: "acoustic")
        case .motionSettled:
            resolver.apply(.moved, atNanoseconds: clock.nowNanoseconds())
            await publishPlacement(evidence: "moved")
            await beginLocateIfPossible()
        case let .edgeExit(edge):
            resolver.apply(.edgeExit(edge), atNanoseconds: clock.nowNanoseconds())
            await publishPlacement(evidence: "edgeExit")
        case let .dragBegan(start):
            updatesContinuation.yield(.dragBegan(start))
        case let .dragEnded(end):
            updatesContinuation.yield(.dragEnded(end))
        case .hello, .beginLocate, .placementUpdate, .landed:
            break
        }
    }

    public func observe(rssi: Int) async {
        let wasDetached = detachment.isDetached
        let isDetached = detachment.observe(rssi: rssi)
        guard isDetached != wasDetached else { return }
        resolver.setDetached(isDetached)
        await publishPlacement(evidence: "proximity")
    }

    private func beginLocateIfPossible() async {
        let canPlay = await audioRoute.canPlayUltrasound()
        updatesContinuation.yield(.audioRoute(canPlayUltrasound: canPlay))
        if canPlay {
            await link.send(.beginLocate)
        }
    }

    private func publishPlacement(evidence: String) async {
        let placement = resolver.placement(atNanoseconds: clock.nowNanoseconds())
        updatesContinuation.yield(.placement(placement, evidence: evidence))
        await placementStore.save(placement.distribution)
        await link.send(.placementUpdate(placement))
    }

    private func startPinging() {
        pingTask?.cancel()
        pingTask = Task { [link, clock] in
            var sent = 0
            while !Task.isCancelled {
                await link.send(.clockPing(originNs: clock.nowNanoseconds()))
                sent += 1
                let interval = sent < Self.burstPingCount ? Self.burstPingInterval : Self.steadyPingInterval
                try? await Task.sleep(for: interval)
            }
        }
    }
}
