public struct ClockSample: Sendable, Equatable {
    public let remoteAheadNanoseconds: Int64
    public let roundTripNanoseconds: Int64

    public init(originNs: UInt64, remoteReceiveNs: UInt64, remoteTransmitNs: UInt64, destinationNs: UInt64) {
        let origin = Int64(truncatingIfNeeded: originNs)
        let remoteReceive = Int64(truncatingIfNeeded: remoteReceiveNs)
        let remoteTransmit = Int64(truncatingIfNeeded: remoteTransmitNs)
        let destination = Int64(truncatingIfNeeded: destinationNs)
        remoteAheadNanoseconds = ((remoteReceive - origin) + (remoteTransmit - destination)) / 2
        roundTripNanoseconds = (destination - origin) - (remoteTransmit - remoteReceive)
    }
}

public struct ClockOffsetEstimator: Sendable, Equatable {
    private static let capacity = 16
    private var samples: [ClockSample] = []

    public init() {}

    public mutating func add(_ sample: ClockSample) {
        samples.append(sample)
        if samples.count > Self.capacity {
            samples.removeFirst()
        }
    }

    public var bestSample: ClockSample? {
        samples.min { $0.roundTripNanoseconds < $1.roundTripNanoseconds }
    }

    public func localTimestamp(fromRemote remoteNs: UInt64) -> UInt64? {
        guard let bestSample else { return nil }
        return UInt64(truncatingIfNeeded: Int64(truncatingIfNeeded: remoteNs) - bestSample.remoteAheadNanoseconds)
    }
}
