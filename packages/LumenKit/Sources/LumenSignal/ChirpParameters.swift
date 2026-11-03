public struct ChirpParameters: Sendable, Equatable {
    public let startFrequencyHz: Double
    public let endFrequencyHz: Double
    public let durationSeconds: Double
    public let sampleRateHz: Double

    /// 17.5–20.5 kHz: above most adults' hearing, below the MacBook speakers' rolloff.
    public static let initial = ChirpParameters(
        startFrequencyHz: 17500,
        endFrequencyHz: 20500,
        durationSeconds: 0.04,
        sampleRateHz: 48000
    )
}
