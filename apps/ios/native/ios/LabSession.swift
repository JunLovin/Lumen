import Foundation
import LumenApplication
import LumenDomain
import LumenProximity
import LumenSignal
import LumenTransport

enum PlacementError: String, Error {
    case linkDown = "link_down"
    case lowSignal = "low_signal"
    case microphoneDenied = "microphone_denied"
    case microphoneUnavailable = "microphone_unavailable"
}

struct PlacementMeasurement {
    let estimate: AcousticEstimate
    let pairs: [ChirpPairArrival]
    let curve: [Float]
}

actor LabSession {
    private static let pairsPerMeasurement = 3
    // Wider than the plan's 300 ms: it absorbs network and Mac audio start latency before the 140 ms pair.
    private static let recordingSeconds = 0.5
    private static let curvePointCount = 240

    private let link: PhoneSecureLink
    private let pairing: PairNearbyDevice
    private let advertiser = PhoneProximityAdvertiser()
    private let clock = SystemClockAdapter()
    private let recorder = MicrophoneRecorder()
    private let frames: AsyncStream<DragFrameSample>.Continuation
    private var isConnected = false
    private var hasStarted = false
    private(set) var pairingStage: PairingStage = .idle
    private var nextRequestID: UInt32 = 1
    private var lastRecording: MicrophoneRecording?

    init() {
        let link = PhoneSecureLink(version: ProtocolInfoAdapter().localProtocolVersion)
        self.link = link
        pairing = PairNearbyDevice(
            trustStore: KeychainTrustStore(service: "com.junlovin.lumen"),
            identityFactory: IdentityFactoryAdapter(),
            pairing: PairingInitiator(),
            proximity: nil,
            link: link,
            clock: SystemClockAdapter(),
            deviceName: "iPhone",
            detector: NearbyDetector(minimumRSSI: 0, dwellNanoseconds: 0)
        )
        let (stream, continuation) = AsyncStream.makeStream(of: DragFrameSample.self)
        frames = continuation
        Task {
            for await frame in stream {
                await link.send(.dragFrame(frame))
            }
        }
    }

    nonisolated func enqueue(_ frame: DragFrameSample) {
        frames.yield(frame)
    }

    nonisolated var nowNanoseconds: UInt64 {
        clock.nowNanoseconds()
    }

    var connected: Bool {
        isConnected
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await consumeEvents() }
        Task { await consumePairing() }
        await pairing.start()
    }

    func forgetPairing() async {
        await pairing.forget()
    }

    func reconnect() async {
        await link.reconnectNow()
    }

    func probeFileChannel() async -> Bool {
        await link.probeFileChannel()
    }

    private func consumePairing() async {
        for await stage in pairing.stages {
            pairingStage = stage
            switch stage {
            case .searching, .exchanging, .awaitingConfirmation, .failed:
                advertiser.start()
            case .paired, .idle:
                advertiser.stop()
            }
        }
    }

    func measurePlacement() async throws -> PlacementMeasurement {
        guard isConnected else { throw PlacementError.linkDown }
        var pairs: [ChirpPairArrival] = []
        var curve: [Float] = []
        let requestID = nextRequestID
        nextRequestID += 1
        for _ in 0 ..< Self.pairsPerMeasurement {
            let recording = try await record(requestID: requestID)
            let parameters = ChirpParameters.initial
            let template = ChirpGenerator.chirp(parameters, sampleRate: recording.sampleRate)
            let envelope = MatchedFilter(template: template).envelope(of: recording.samples)
            curve = CorrelationCurve.downsample(envelope, pointCount: Self.curvePointCount)
            if let pair = ChirpPairEstimator.estimate(
                envelope: envelope,
                parameters: parameters,
                sampleRate: recording.sampleRate
            ) {
                pairs.append(pair)
            }
        }
        guard let estimate = AcousticEstimate(pairs: pairs, parameters: .initial) else {
            throw PlacementError.lowSignal
        }
        await report(estimate, requestID: requestID)
        return PlacementMeasurement(estimate: estimate, pairs: pairs, curve: curve)
    }

    #if DEBUG
        func exportLastRecording() throws -> URL? {
            guard let lastRecording else { return nil }
            let rate = Int(lastRecording.sampleRate)
            let url = FileManager.default.temporaryDirectory
                .appending(path: "lumen-recording-\(rate)hz-\(UUID().uuidString).f32")
            let data = lastRecording.samples.withUnsafeBytes { Data($0) }
            try data.write(to: url)
            return url
        }
    #endif

    private func record(requestID: UInt32) async throws -> MicrophoneRecording {
        let link = link
        do {
            let recording = try await recorder.record(seconds: Self.recordingSeconds) {
                await link.send(.playChirpPair(requestID: requestID))
            }
            #if DEBUG
                lastRecording = recording
            #endif
            return recording
        } catch MicrophoneError.denied {
            throw PlacementError.microphoneDenied
        } catch {
            throw PlacementError.microphoneUnavailable
        }
    }

    private func report(_ estimate: AcousticEstimate, requestID: UInt32) async {
        await link.send(.acousticReport(AcousticReading(
            requestID: requestID,
            tauMicroseconds: Float(estimate.tauSeconds * 1_000_000),
            levelDifferenceDecibels: estimate.levelDifferenceDecibels,
            snrDecibels: estimate.snrDecibels,
            acceptedPairs: Int32(estimate.acceptedPairs)
        )))
    }

    private func consumeEvents() async {
        for await event in link.events {
            switch event {
            case .connected:
                isConnected = true
            case .disconnected, .incompatible:
                isConnected = false
            case let .received(.clockPing(originNs)):
                let now = clock.nowNanoseconds()
                await link.send(.clockPong(originNs: originNs, receiveNs: now, transmitNs: now))
            case .received:
                break
            }
        }
    }
}
