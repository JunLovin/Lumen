public struct ChirpParameters: Sendable, Equatable {
    public let startFrequencyHz: Double
    public let endFrequencyHz: Double
    public let durationSeconds: Double
    public let pairOnsetIntervalSeconds: Double
    public let pairSearchToleranceSeconds: Double
    public let firstArrivalFraction: Float
    public let firstArrivalLookbackSeconds: Double
    public let minimumSNRDecibels: Float

    /// 17.5–20.5 kHz: above most adults' hearing, below the MacBook speakers' rolloff.
    /// Onset interval is the 40 ms chirp plus the plan's 60 ms gap, so τ compares onsets.
    /// Tolerance of 3 ms: a MacBook Air M4 measured about 1 ms of inter-channel bias on top of the 0.8 ms geometry.
    /// First arrival: recordings show echoes up to 25 ms later, often stronger than the direct path.
    public static let initial = ChirpParameters(
        startFrequencyHz: 17500,
        endFrequencyHz: 20500,
        durationSeconds: 0.04,
        pairOnsetIntervalSeconds: 0.1,
        pairSearchToleranceSeconds: 0.003,
        firstArrivalFraction: 0.3,
        firstArrivalLookbackSeconds: 0.002,
        minimumSNRDecibels: 12
    )
}
