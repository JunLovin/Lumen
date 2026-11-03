public struct ChirpParameters: Sendable, Equatable {
    public let startFrequencyHz: Double
    public let endFrequencyHz: Double
    public let durationSeconds: Double
    public let pairOnsetIntervalSeconds: Double
    public let maximumTauSeconds: Double
    public let centerTauSeconds: Double
    public let minimumSNRDecibels: Float

    /// 17.5–20.5 kHz: above most adults' hearing, below the MacBook speakers' rolloff.
    /// Onset interval is the 40 ms chirp plus the plan's 60 ms gap, so τ compares onsets.
    /// Maximum τ leaves margin over 30 cm of speaker separation at 343 m/s (0.87 ms).
    public static let initial = ChirpParameters(
        startFrequencyHz: 17500,
        endFrequencyHz: 20500,
        durationSeconds: 0.04,
        pairOnsetIntervalSeconds: 0.1,
        maximumTauSeconds: 0.0015,
        centerTauSeconds: 0.0001,
        minimumSNRDecibels: 12
    )
}
