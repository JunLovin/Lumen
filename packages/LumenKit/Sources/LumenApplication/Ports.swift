import LumenDomain

public protocol ProtocolInfoPort: Sendable {
    var localProtocolVersion: ProtocolVersion { get }
}

public protocol ClockPort: Sendable {
    func nowNanoseconds() -> UInt64
}

public enum AudioChannel: Sendable, Equatable {
    case left
    case right
}

public protocol ChirpPlayerPort: Sendable {
    func playPair(amplitude: Float) async
    func playTestTone(on channel: AudioChannel) async
}

public enum PeerMessage: Sendable, Equatable {
    case hello(ProtocolVersion)
    case clockPing(originNs: UInt64)
    case clockPong(originNs: UInt64, receiveNs: UInt64, transmitNs: UInt64)
    case dragFrame(DragFrameSample)
    case playChirpPair(requestID: UInt32)
    case acousticReport(AcousticReading)
    case motionSettled
    case beginLocate
    case edgeExit(PhoneEdge)
    case placementUpdate(Placement)
    case dragBegan(DragStart)
    case dragEnded(DragEnd)
    case landed(session: UInt32)
    case transferOffer(TransferOffer)
    case transferCancel(transferID: UInt32)
    case transferPreparing(transferID: UInt32, fraction: Double)
}

public enum PeerEvent: Sendable, Equatable {
    case connected
    case disconnected
    case incompatible(supported: ProtocolVersion)
    case received(PeerMessage)
}

public protocol PeerLinkPort: Sendable {
    var events: AsyncStream<PeerEvent> { get }
    func start() async -> Bool
    func send(_ message: PeerMessage) async
}

public protocol SecureLinkPort: PeerLinkPort {
    func activate(identity: LocalIdentity, peer: PairedDevice) async
    func deactivate() async
}

public protocol TrustStorePort: Sendable {
    func loadIdentity() async -> LocalIdentity?
    func save(identity: LocalIdentity) async -> Bool
    func loadPeer() async -> PairedDevice?
    func save(peer: PairedDevice) async -> Bool
    func forgetPeer() async
}

public protocol IdentityFactoryPort: Sendable {
    func makeIdentity(name: String) -> LocalIdentity
}

public protocol PairingPort: Sendable {
    func begin(identity: LocalIdentity) async -> AsyncStream<PairingStage>
    func confirm() async
    func cancel() async
}

public protocol ProximityPort: Sendable {
    func rssiReadings() async -> AsyncStream<Int>
    func stop() async
}

public protocol AudioRoutePort: Sendable {
    func canPlayUltrasound() async -> Bool
}

public protocol PlacementStorePort: Sendable {
    func load() async -> PlacementDistribution?
    func save(_ distribution: PlacementDistribution) async
}

public protocol FileSinkPort: Sendable {
    var updates: AsyncStream<TransferUpdate> { get }
    func register(_ offer: TransferOffer) async
    func resumeOffset(transferID: UInt32, resourceIndex: UInt32) async -> UInt64?
    func append(_ bytes: [UInt8], transferID: UInt32, resourceIndex: UInt32) async -> Bool
    func finish(transferID: UInt32, resourceIndex: UInt32, sha256: [UInt8]) async -> Bool
    func cancel(transferID: UInt32) async
}

public protocol FileSourcePort: Sendable {
    func prepareBatch(paths: [String], isDirect: Bool) async -> TransferOffer?
    func discard(transferID: UInt32) async
}
