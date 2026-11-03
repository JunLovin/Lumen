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

    public static func estimate(
        envelope: [Float],
        parameters: ChirpParameters,
        sampleRate: Double
    ) -> ChirpPairArrival? {
        let onsetInterval = Int((parameters.pairOnsetIntervalSeconds * sampleRate).rounded())
        let tolerance = Int((parameters.maximumTauSeconds * sampleRate).rounded())
        guard let strongest = envelope.max(), strongest > 0 else { return nil }

        var best: Candidate?
        for left in envelope.indices where envelope[left] > strongest / 4 {
            let lower = left + onsetInterval - tolerance
            let upper = min(left + onsetInterval + tolerance, envelope.count - 1)
            guard lower <= upper else { break }
            let right = (lower ... upper).max { envelope[$0] < envelope[$1] } ?? lower
            let score = envelope[left] + envelope[right]
            if score > best?.score ?? 0 {
                best = Candidate(left: left, right: right, score: score)
            }
        }
        guard let best else { return nil }

        let leftOnset = refinedPeak(envelope, at: best.left)
        let rightOnset = refinedPeak(envelope, at: best.right)
        let leftLevel = envelope[best.left]
        let rightLevel = max(envelope[best.right], .leastNonzeroMagnitude)
        let floorLevel = max(median(envelope), .leastNonzeroMagnitude)
        return ChirpPairArrival(
            tauSeconds: (rightOnset - leftOnset) / sampleRate - Double(onsetInterval) / sampleRate,
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

    private static func refinedPeak(_ envelope: [Float], at index: Int) -> Double {
        guard index > 0, index < envelope.count - 1 else { return Double(index) }
        let before = envelope[index - 1]
        let peak = envelope[index]
        let after = envelope[index + 1]
        let curvature = before - 2 * peak + after
        guard curvature < 0 else { return Double(index) }
        return Double(index) + Double((before - after) / (2 * curvature))
    }
}
