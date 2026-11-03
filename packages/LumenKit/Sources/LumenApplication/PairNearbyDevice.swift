import LumenDomain

public actor PairNearbyDevice {
    public nonisolated let stages: AsyncStream<PairingStage>
    private let stagesContinuation: AsyncStream<PairingStage>.Continuation
    private let trustStore: any TrustStorePort
    private let identityFactory: any IdentityFactoryPort
    private let pairing: any PairingPort
    private let proximity: (any ProximityPort)?
    private let link: any SecureLinkPort
    private let clock: any ClockPort
    private let deviceName: String
    private let detector: NearbyDetector
    private var task: Task<Void, Never>?

    public init(
        trustStore: any TrustStorePort,
        identityFactory: any IdentityFactoryPort,
        pairing: any PairingPort,
        proximity: (any ProximityPort)?,
        link: any SecureLinkPort,
        clock: any ClockPort,
        deviceName: String,
        detector: NearbyDetector
    ) {
        (stages, stagesContinuation) = AsyncStream.makeStream()
        self.trustStore = trustStore
        self.identityFactory = identityFactory
        self.pairing = pairing
        self.proximity = proximity
        self.link = link
        self.clock = clock
        self.deviceName = deviceName
        self.detector = detector
    }

    public func start() async {
        guard task == nil else { return }
        let identity = await loadOrCreateIdentity()
        if let peer = await trustStore.loadPeer() {
            stagesContinuation.yield(.paired(peer))
            await link.activate(identity: identity, peer: peer)
            return
        }
        stagesContinuation.yield(.searching)
        task = Task { await pair(identity: identity) }
    }

    public func confirm() async {
        await pairing.confirm()
    }

    public func forget() async {
        task?.cancel()
        task = nil
        await pairing.cancel()
        await proximity?.stop()
        await link.deactivate()
        await trustStore.forgetPeer()
        await start()
    }

    private func pair(identity: LocalIdentity) async {
        await waitUntilNear()
        guard !Task.isCancelled else { return }
        for await stage in await pairing.begin(identity: identity) {
            guard !Task.isCancelled else { return }
            await handle(stage, identity: identity)
        }
    }

    private func handle(_ stage: PairingStage, identity: LocalIdentity) async {
        switch stage {
        case let .paired(peer):
            guard await trustStore.save(peer: peer) else {
                stagesContinuation.yield(.failed(.verificationFailed))
                return
            }
            stagesContinuation.yield(stage)
            await proximity?.stop()
            await link.activate(identity: identity, peer: peer)
        default:
            stagesContinuation.yield(stage)
        }
    }

    private func waitUntilNear() async {
        guard let proximity else { return }
        var detector = detector
        for await rssi in await proximity.rssiReadings() {
            if detector.observe(rssi: rssi, atNanoseconds: clock.nowNanoseconds()) {
                return
            }
        }
    }

    private func loadOrCreateIdentity() async -> LocalIdentity {
        if let identity = await trustStore.loadIdentity() {
            return identity
        }
        let identity = identityFactory.makeIdentity(name: deviceName)
        _ = await trustStore.save(identity: identity)
        return identity
    }
}
