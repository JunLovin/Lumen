public enum PhoneEdge: Int, CaseIterable, Sendable, Codable {
    case top
    case right
    case bottom
    case left

    public var placementWhenFacingMac: PlacementSide {
        switch self {
        case .right: .left
        case .left: .right
        case .top: .below
        case .bottom: .above
        }
    }

    public static func facingMac(from side: PlacementSide) -> PhoneEdge? {
        allCases.first { $0.placementWhenFacingMac == side }
    }

    public func rotated(clockwiseQuarterTurns turns: Int) -> PhoneEdge {
        let count = Self.allCases.count
        let index = ((rawValue - turns) % count + count) % count
        return PhoneEdge(rawValue: index) ?? self
    }
}

public enum PlacementEvidence: Sendable, Equatable {
    case acoustic(tauMicroseconds: Float, levelDifferenceDecibels: Float, snrDecibels: Float)
    case edgeExit(PhoneEdge)
    case moved
}

public struct Placement: Sendable, Equatable, Codable {
    public let side: PlacementSide
    public let confidence: Double
    public let distribution: PlacementDistribution
    public let isDetached: Bool

    public init(side: PlacementSide, confidence: Double, distribution: PlacementDistribution, isDetached: Bool) {
        self.side = side
        self.confidence = confidence
        self.distribution = distribution
        self.isDetached = isDetached
    }
}

public struct PlacementResolver: Sendable, Equatable {
    /// Speakers measured ±230 µs apart at the corners of a MacBook Air M4; 100 µs leaves room for noise.
    private static let centerTauMicroseconds: Float = 100
    private static let minimumSNRDecibels: Float = 12
    private static let confidenceHalfLifeNanoseconds = 600.0 * 1_000_000_000
    private static let retainedAfterMoving = 0.2

    private var distribution: PlacementDistribution
    private var lastUpdateNanoseconds: UInt64
    private var isDetached = false

    public init(distribution: PlacementDistribution = .uncertain, atNanoseconds now: UInt64 = 0) {
        self.distribution = distribution
        lastUpdateNanoseconds = now
    }

    public mutating func apply(_ evidence: PlacementEvidence, atNanoseconds now: UInt64) {
        decay(to: now)
        switch evidence {
        case let .acoustic(tau, level, snr):
            guard snr >= Self.minimumSNRDecibels else { return }
            distribution.multiply(by: Self.likelihoods(tau: tau, level: level))
        case let .edgeExit(edge):
            distribution.multiply(by: Self.likelihoods(
                certain: edge.placementWhenFacingMac,
                certainty: 0.95,
                rest: 0.01
            ))
        case .moved:
            distribution.relax(retaining: Self.retainedAfterMoving)
        }
    }

    public mutating func setDetached(_ isDetached: Bool) {
        self.isDetached = isDetached
    }

    public mutating func placement(atNanoseconds now: UInt64) -> Placement {
        decay(to: now)
        let side = distribution.mostLikely
        return Placement(
            side: isDetached ? .unknown : side,
            confidence: side == .unknown ? 0 : distribution.probability(of: side),
            distribution: distribution,
            isDetached: isDetached
        )
    }

    private mutating func decay(to now: UInt64) {
        guard now > lastUpdateNanoseconds else { return }
        let elapsed = Double(now - lastUpdateNanoseconds)
        distribution.relax(retaining: Self.halved(elapsed / Self.confidenceHalfLifeNanoseconds))
        lastUpdateNanoseconds = now
    }

    /// Piecewise-linear 2^-x: the domain imports no math library, and precision here does not matter.
    private static func halved(_ halfLives: Double) -> Double {
        var retained = 1.0
        var remaining = halfLives
        while remaining >= 1 {
            retained /= 2
            remaining -= 1
        }
        return retained * (1 - remaining / 2)
    }

    private static func likelihoods(tau: Float, level: Float) -> [PlacementSide: Double] {
        if abs(tau) < centerTauMicroseconds {
            return [.left: 0.05, .right: 0.05, .below: 0.6, .above: 0.2, .unknown: 0.1]
        }
        let side: PlacementSide = tau < 0 ? .right : .left
        let opposite: PlacementSide = tau < 0 ? .left : .right
        let levelAgrees = (level < 0) == (tau < 0)
        guard !levelAgrees else {
            return likelihoods(certain: side, certainty: 0.9, rest: 0.02)
        }
        return [side: 0.5, opposite: 0.3, .below: 0.1, .above: 0.1, .unknown: 0.3]
    }

    private static func likelihoods(
        certain side: PlacementSide,
        certainty: Double,
        rest: Double
    ) -> [PlacementSide: Double] {
        var values = Dictionary(uniqueKeysWithValues: PlacementSide.allCases.map { ($0, rest) })
        values[side] = certainty
        return values
    }
}
