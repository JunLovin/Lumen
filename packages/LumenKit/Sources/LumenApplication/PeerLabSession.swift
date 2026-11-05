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
    private var estimator = ClockOffsetEstimator()
    private var chirpAmplitude: Float
    private var pingTask: Task<Void, Never>?

    public init(
        link: any PeerLinkPort,
        clock: any ClockPort,
        chirpPlayer: any ChirpPlayerPort,
        chirpAmplitude: Float
    ) {
        (updates, updatesContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(256))
        self.link = link
        self.clock = clock
        self.chirpPlayer = chirpPlayer
        self.chirpAmplitude = chirpAmplitude
    }

    public func run() async {
        for await event in link.events {
            await handle(event)
        }
    }

    public func setChirpAmplitude(_ amplitude: Float) {
        chirpAmplitude = amplitude
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
            await chirpPlayer.playPair(amplitude: chirpAmplitude)
        case let .acousticReport(reading):
            updatesContinuation.yield(.acousticReport(reading))
        case .hello:
            break
        }
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
