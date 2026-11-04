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
    case transfer(TransferUpdate)
    case directTransfer(TransferOffer)
    case sendingFiles(TransferOffer)
}
