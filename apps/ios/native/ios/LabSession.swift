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

    private let link: PhoneSecureLink
    private let pairing: PairNearbyDevice
    private let advertiser = PhoneProximityAdvertiser()
    private let clock = SystemClockAdapter()
    private let locator = AcousticLocator()
    private let frames: AsyncStream<DragFrameSample>.Continuation
    private var isConnected = false
    private var hasStarted = false
    private(set) var pairingStage: PairingStage = .idle
    private(set) var placement: Placement?
    private let motion = MotionMonitor()
    private var settleDetector = MotionSettleDetector(
        movingAcceleration: LabSession.movingAcceleration,
        quietNanoseconds: LabSession.quietNanoseconds
    )
    private var isLocating = false
    private var lastLocationFailure: PlacementError?
    private var referenceYawRadians: Double?
    private var referenceEdge: PhoneEdge?
    private var currentYawRadians: Double?
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

    private func consumeMotion() async {
        for await sample in motion.start() {
            currentYawRadians = sample.yawRadians
            if referenceYawRadians == nil {
                referenceYawRadians = sample.yawRadians
            }
            if settleDetector.observe(acceleration: sample.acceleration, atNanoseconds: clock.nowNanoseconds()) {
                await link.send(.motionSettled)
            }
        }
    }

    private func locate() async {
        guard !isLocating else { return }
        isLocating = true
        defer { isLocating = false }
        do {
            _ = try await measurePlacement()
            lastLocationFailure = nil
        } catch let error as PlacementError {
            lastLocationFailure = error
        } catch {
            lastLocationFailure = .microphoneUnavailable
        }
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
        let measurement = try await locator.measure {
            await link.send(.playChirpPair(requestID: requestID))
        }
        let estimate = measurement.estimate
        await link.send(.acousticReport(AcousticReading(
            requestID: requestID,
            tauMicroseconds: Float(estimate.tauSeconds * 1_000_000),
            levelDifferenceDecibels: estimate.levelDifferenceDecibels,
            snrDecibels: estimate.snrDecibels,
            acceptedPairs: Int32(estimate.acceptedPairs)
        )))
        return measurement
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
            case .received:
                break
            }
        }
    }
}
