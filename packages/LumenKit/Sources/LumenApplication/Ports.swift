import LumenDomain

public protocol ProtocolInfoPort: Sendable {
    var localProtocolVersion: ProtocolVersion { get }
}

public protocol ClockPort: Sendable {
    func nowNanoseconds() -> UInt64
}

public protocol ChirpPlayerPort: Sendable {
    func playPair(amplitude: Float) async
}

public enum PeerMessage: Sendable, Equatable {
    case hello(ProtocolVersion)
    case clockPing(originNs: UInt64)
    case clockPong(originNs: UInt64, receiveNs: UInt64, transmitNs: UInt64)
    case dragFrame(DragFrameSample)
    case playChirpPair(requestID: UInt32)
    case acousticReport(AcousticReading)
}

public enum PeerEvent: Sendable, Equatable {
    case connected
    case disconnected
    case received(PeerMessage)
}

public protocol PeerLinkPort: Sendable {
    var events: AsyncStream<PeerEvent> { get }
    func start() async -> Bool
    func send(_ message: PeerMessage) async
}
