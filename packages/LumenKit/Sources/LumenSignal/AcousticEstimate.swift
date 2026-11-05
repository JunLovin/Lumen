public struct AcousticEstimate: Sendable, Equatable {
    public let tauSeconds: Double
    public let levelDifferenceDecibels: Float
    public let snrDecibels: Float
    public let acceptedPairs: Int

    public init?(pairs: [ChirpPairArrival], parameters: ChirpParameters) {
        let accepted = pairs.filter { $0.snrDecibels >= parameters.minimumSNRDecibels }
        guard !accepted.isEmpty else { return nil }
        tauSeconds = Double(ChirpPairEstimator.median(accepted.map { Float($0.tauSeconds) }))
        levelDifferenceDecibels = ChirpPairEstimator.median(accepted.map(\.levelDifferenceDecibels))
        snrDecibels = ChirpPairEstimator.median(accepted.map(\.snrDecibels))
        acceptedPairs = accepted.count
    }
}
