import Foundation

public struct ChirpPairArrival: Sendable, Equatable {
    public let tauSeconds: Double
    public let levelDifferenceDecibels: Float
    public let snrDecibels: Float

    public init(tauSeconds: Double, levelDifferenceDecibels: Float, snrDecibels: Float) {
        self.tauSeconds = tauSeconds
        self.levelDifferenceDecibels = levelDifferenceDecibels
        self.snrDecibels = snrDecibels
    }
}

public enum ChirpPairEstimator {
    private struct Candidate {
        let left: Int
        let right: Int
        let score: Float
    }

    private static let candidateFloorFraction: Float = 1.0 / 32

    public static func estimate(
        envelope: [Float],
        parameters: ChirpParameters,
        sampleRate: Double
    ) -> ChirpPairArrival? {
        let onsetInterval = Int((parameters.pairOnsetIntervalSeconds * sampleRate).rounded())
        guard let best = strongestPair(envelope, parameters: parameters, sampleRate: sampleRate) else { return nil }

        let lookback = Int((parameters.firstArrivalLookbackSeconds * sampleRate).rounded())
        let fraction = parameters.firstArrivalFraction
        let leftOnset = firstArrival(envelope, peak: best.left, lookback: lookback, fraction: fraction)
        let rightOnset = firstArrival(envelope, peak: best.right, lookback: lookback, fraction: fraction)
        let leftLevel = envelope[best.left]
        let rightLevel = max(envelope[best.right], .leastNonzeroMagnitude)
        let floorLevel = max(median(envelope), .leastNonzeroMagnitude)
        return ChirpPairArrival(
            tauSeconds: (rightOnset - leftOnset - Double(onsetInterval)) / sampleRate,
            levelDifferenceDecibels: 20 * log10(leftLevel / rightLevel),
            snrDecibels: 20 * log10(min(leftLevel, rightLevel) / floorLevel)
        )
    }

    public static func median(_ values: [Float]) -> Float {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func strongestPair(
        _ envelope: [Float],
        parameters: ChirpParameters,
        sampleRate: Double
    ) -> Candidate? {
        let onsetInterval = Int((parameters.pairOnsetIntervalSeconds * sampleRate).rounded())
        let tolerance = Int((parameters.pairSearchToleranceSeconds * sampleRate).rounded())
        guard let strongest = envelope.max(), strongest > 0 else { return nil }

        var best: Candidate?
        for left in envelope.indices where envelope[left] > strongest * candidateFloorFraction {
            let lower = left + onsetInterval - tolerance
            let upper = min(left + onsetInterval + tolerance, envelope.count - 1)
            guard lower <= upper else { break }
            let right = (lower ... upper).max { envelope[$0] < envelope[$1] } ?? lower
            let score = envelope[left] + envelope[right]
            if score > best?.score ?? 0 {
                best = Candidate(left: left, right: right, score: score)
            }
        }
        return best
    }

    private static func firstArrival(_ envelope: [Float], peak: Int, lookback: Int, fraction: Float) -> Double {
        let threshold = envelope[peak] * fraction
        let start = max(peak - lookback, 0)
        let crossing = (start ... peak).first { envelope[$0] >= threshold } ?? peak
        guard crossing > start else { return Double(crossing) }
        let before = envelope[crossing - 1]
        let span = envelope[crossing] - before
        guard span > 0 else { return Double(crossing) }
        return Double(crossing - 1) + Double((threshold - before) / span)
    }
}
