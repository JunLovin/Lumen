import Accelerate
import Foundation

public enum ChirpGenerator {
    public static func chirp(_ parameters: ChirpParameters, sampleRate: Double) -> [Float] {
        let count = Int((parameters.durationSeconds * sampleRate).rounded())
        let sweepRate = (parameters.endFrequencyHz - parameters.startFrequencyHz) / parameters.durationSeconds
        let samples = (0 ..< count).map { index -> Float in
            let time = Double(index) / sampleRate
            let phase = 2 * Double.pi * (parameters.startFrequencyHz * time + sweepRate * time * time / 2)
            return Float(sin(phase))
        }
        let window = vDSP.window(
            ofType: Float.self,
            usingSequence: .hanningDenormalized,
            count: count,
            isHalfWindow: false
        )
        return vDSP.multiply(samples, window)
    }

    public static func stereoPair(
        _ parameters: ChirpParameters,
        sampleRate: Double,
        amplitude: Float
    ) -> (left: [Float], right: [Float]) {
        let chirp = vDSP.multiply(amplitude, chirp(parameters, sampleRate: sampleRate))
        let onsetInterval = Int((parameters.pairOnsetIntervalSeconds * sampleRate).rounded())
        var left = [Float](repeating: 0, count: onsetInterval + chirp.count)
        var right = left
        left.replaceSubrange(0 ..< chirp.count, with: chirp)
        right.replaceSubrange(onsetInterval ..< onsetInterval + chirp.count, with: chirp)
        return (left, right)
    }
}
