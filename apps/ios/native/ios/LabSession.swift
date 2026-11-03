import Foundation
import LumenApplication
import LumenDomain
import LumenProximity
import LumenSignal
import LumenTransport

actor LabSession {
    /// In g: a phone resting on a table reads well under this, and a phone being moved well over it.
    private static let movingAcceleration = 0.05
    private static let quietNanoseconds: UInt64 = 1_000_000_000
    private static let locatedConfidence = 0.8

    let link: PhoneSecureLink
    private let pairing: PairNearbyDevice
    private let advertiser = PhoneProximityAdvertiser()
    let clock = SystemClockAdapter()
    private let locator = AcousticLocator()
    private let frames: AsyncStream<DragFrameSample>.Continuation
    private var isConnected = false
    private var hasStarted = false
    private(set) var pairingStage: PairingStage = .idle
    private(set) var placement: Placement?
    let motion = MotionMonitor()
    var settleDetector = MotionSettleDetector(
        movingAcceleration: LabSession.movingAcceleration,
        quietNanoseconds: LabSession.quietNanoseconds
    )
    var isLocating = false
    var hasPendingLocate = false
    var lastLocationFailure: PlacementError?
    var settledAtNanoseconds: UInt64?
    private(set) var lastLocateMilliseconds: Double?
    var referenceYawRadians: Double?
    private var referenceEdge: PhoneEdge?
    var currentYawRadians: Double?
    private var nextRequestID: UInt32 = 1

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
        Task { await consumeMotion() }
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

    func reportEdgeExit(_ edge: PhoneEdge) async {
        referenceYawRadians = currentYawRadians
        referenceEdge = edge
        await link.send(.edgeExit(edge))
    }

    var facingEdge: PhoneEdge? {
        guard let edge = referenceEdge ?? placement.flatMap({ PhoneEdge.facingMac(from: $0.side) }) else { return nil }
        guard let reference = referenceYawRadians, let current = currentYawRadians else { return edge }
        // CoreMotion yaw grows counter-clockwise seen from above; a clockwise turn is a negative change.
        let turns = Int(((reference - current) / (Double.pi / 2)).rounded())
        return edge.rotated(clockwiseQuarterTurns: turns)
    }

    var locationFailure: String? {
        lastLocationFailure?.rawValue
    }

    private func consumePairing() async {
        for await stage in pairing.stages {
            pairingStage = stage
            switch stage {
            case .searching, .exchanging, .awaitingConfirmation, .failed, .paired:
                advertiser.start()
            case .idle:
                advertiser.stop()
            }
        }
    }

    func measurePlacement() async throws -> PlacementMeasurement {
        guard isConnected else { throw PlacementError.linkDown }
        let requestID = nextRequestID
        nextRequestID += 1
        let link = link
        return try await locator.measure {
            await link.send(.playChirpPair(requestID: requestID))
        } onPair: { pair in
            await link.send(.acousticReport(AcousticReading(
                requestID: requestID,
                tauMicroseconds: Float(pair.tauSeconds * 1_000_000),
                levelDifferenceDecibels: pair.levelDifferenceDecibels,
                snrDecibels: pair.snrDecibels,
                acceptedPairs: 1
            )))
        }
    }

    #if DEBUG
        func exportLastRecording() async throws -> URL? {
            try await locator.exportLastRecording()
        }
    #endif

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
            case .received(.beginLocate):
                Task { await locate() }
            case let .received(.placementUpdate(update)):
                if update.side != placement?.side {
                    referenceEdge = nil
                    referenceYawRadians = currentYawRadians
                }
                placement = update
                if let settledAt = settledAtNanoseconds, update.confidence >= Self.locatedConfidence {
                    lastLocateMilliseconds = Double(clock.nowNanoseconds() - settledAt) / 1_000_000
                    settledAtNanoseconds = nil
                }
            case .received:
                break
            }
        }
    }
}
