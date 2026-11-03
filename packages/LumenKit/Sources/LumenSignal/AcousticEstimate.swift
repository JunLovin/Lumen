public enum AcousticSide: String, Sendable, Equatable {
    case left
    case right
    case center
}

public struct AcousticEstimate: Sendable, Equatable {
    public let tauSeconds: Double
    public let levelDifferenceDecibels: Float
    public let snrDecibels: Float
    public let acceptedPairs: Int
    public let side: AcousticSide

    public init?(pairs: [ChirpPairArrival], parameters: ChirpParameters) {
        let accepted = pairs.filter { $0.snrDecibels >= parameters.minimumSNRDecibels }
        guard !accepted.isEmpty else { return nil }
        let tau = Double(ChirpPairEstimator.median(accepted.map { Float($0.tauSeconds) }))
        tauSeconds = tau
        levelDifferenceDecibels = ChirpPairEstimator.median(accepted.map(\.levelDifferenceDecibels))
        snrDecibels = ChirpPairEstimator.median(accepted.map(\.snrDecibels))
        acceptedPairs = accepted.count
        if abs(tau) < parameters.centerTauSeconds {
            side = .center
        } else {
            side = tau < 0 ? .right : .left
        }
    }
}
