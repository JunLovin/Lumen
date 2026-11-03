public enum PlacementSide: Int, CaseIterable, Sendable, Codable {
    case left
    case right
    case below
    case above
    case unknown
}

public struct PlacementDistribution: Sendable, Equatable, Codable {
    public static let uncertain = PlacementDistribution(probabilities: [0.1, 0.1, 0.1, 0.1, 0.6])

    public private(set) var probabilities: [Double]

    public init(probabilities: [Double]) {
        self.probabilities = probabilities
    }

    public func probability(of side: PlacementSide) -> Double {
        probabilities[side.rawValue]
    }

    public var mostLikely: PlacementSide {
        let best = probabilities.indices.max { probabilities[$0] < probabilities[$1] } ?? PlacementSide.unknown.rawValue
        return PlacementSide(rawValue: best) ?? .unknown
    }

    public mutating func multiply(by likelihoods: [PlacementSide: Double]) {
        var posterior = PlacementSide.allCases.map { probability(of: $0) * (likelihoods[$0] ?? 0) }
        let total = posterior.reduce(0, +)
        guard total > 0 else {
            self = .uncertain
            return
        }
        posterior = posterior.map { $0 / total }
        probabilities = posterior
    }

    public mutating func relax(retaining fraction: Double) {
        let retained = min(max(fraction, 0), 1)
        probabilities = zip(probabilities, Self.uncertain.probabilities).map { current, uncertain in
            current * retained + uncertain * (1 - retained)
        }
    }
}
