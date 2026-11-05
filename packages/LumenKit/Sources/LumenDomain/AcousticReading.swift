public struct AcousticReading: Sendable, Equatable {
    public let requestID: UInt32
    public let tauMicroseconds: Float
    public let levelDifferenceDecibels: Float
    public let snrDecibels: Float
    public let acceptedPairs: Int32

    public init(
        requestID: UInt32,
        tauMicroseconds: Float,
        levelDifferenceDecibels: Float,
        snrDecibels: Float,
        acceptedPairs: Int32
    ) {
        self.requestID = requestID
        self.tauMicroseconds = tauMicroseconds
        self.levelDifferenceDecibels = levelDifferenceDecibels
        self.snrDecibels = snrDecibels
        self.acceptedPairs = acceptedPairs
    }
}
