import Foundation
import LumenSignal
import Testing

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

private let sampleRate = 48000.0
private let parameters = ChirpParameters.initial

private func recording(
    tauSamples: Int,
    leftGain: Float = 0.2,
    rightGain: Float = 0.2,
    noise: Float = 0.01,
    tone: Float = 0
) -> [Float] {
    var generator = SeededGenerator(state: 42)
    var samples = (0 ..< 24000).map { index -> Float in
        let hum = tone * Float(sin(2 * Double.pi * 440 * Double(index) / sampleRate))
        return Float.random(in: -noise ... noise, using: &generator) + hum
    }
    let chirp = ChirpGenerator.chirp(parameters, sampleRate: sampleRate)
    let leftOnset = 4800
    let rightOnset = leftOnset + Int(parameters.pairOnsetIntervalSeconds * sampleRate) + tauSamples
    for (index, sample) in chirp.enumerated() {
        samples[leftOnset + index] += sample * leftGain
        samples[rightOnset + index] += sample * rightGain
    }
    return samples
}

private func arrival(in samples: [Float]) throws -> ChirpPairArrival {
    let filter = MatchedFilter(template: ChirpGenerator.chirp(parameters, sampleRate: sampleRate))
    let envelope = filter.envelope(of: samples)
    return try #require(ChirpPairEstimator.estimate(envelope: envelope, parameters: parameters, sampleRate: sampleRate))
}

@Test(arguments: [-38, -20, -5, 0, 5, 20, 38])
func recoversTauWithinOneSample(tauSamples: Int) throws {
    let result = try arrival(in: recording(tauSamples: tauSamples))
    #expect(abs(result.tauSeconds - Double(tauSamples) / sampleRate) < 1 / sampleRate)
}

@Test(arguments: [-140, 140])
func recoversBiasedTauBeyondTheGeometricMaximum(tauSamples: Int) throws {
    let result = try arrival(in: recording(tauSamples: tauSamples))
    #expect(abs(result.tauSeconds - Double(tauSamples) / sampleRate) < 1 / sampleRate)
}

@Test func measuresTheDirectPathWhenAnEchoIsStronger() throws {
    let chirp = ChirpGenerator.chirp(parameters, sampleRate: sampleRate)
    var samples = recording(tauSamples: 20, leftGain: 0.1, rightGain: 0.1, noise: 0.001)
    let leftEcho = 4800 + 48
    let rightEcho = 4800 + 4800 + 20 + 72
    for (index, sample) in chirp.enumerated() {
        samples[leftEcho + index] += sample * 0.2
        samples[rightEcho + index] += sample * 0.2
    }
    let result = try arrival(in: samples)
    #expect(abs(result.tauSeconds - 20 / sampleRate) < 4 / sampleRate)
}

@Test func findsAMuchWeakerFirstChirp() throws {
    let result = try arrival(in: recording(tauSamples: 10, leftGain: 0.02, rightGain: 0.2, noise: 0.001))
    #expect(abs(result.levelDifferenceDecibels - -20) < 1)
}

@Test func aLouderRightSpeakerGivesANegativeLevelDifference() throws {
    let result = try arrival(in: recording(tauSamples: -30, leftGain: 0.1, rightGain: 0.2))
    #expect(abs(result.levelDifferenceDecibels - -6) < 1)
}

@Test func ignoresAudibleToneBecauseItIsOutsideTheChirpBand() throws {
    let result = try arrival(in: recording(tauSamples: 25, tone: 0.5))
    #expect(abs(result.tauSeconds - 25 / sampleRate) < 1 / sampleRate)
}

@Test func rejectsPureNoiseThroughLowSNR() throws {
    let result = try arrival(in: recording(tauSamples: 0, leftGain: 0, rightGain: 0, noise: 0.05))
    #expect(AcousticEstimate(pairs: [result], parameters: parameters) == nil)
}

@Test func usesTheMedianOfAcceptedPairs() throws {
    let pairs = [10.0, 500.0, 20.0].map {
        ChirpPairArrival(tauSeconds: $0 / 1_000_000, levelDifferenceDecibels: 0, snrDecibels: 30)
    }
    let estimate = try #require(AcousticEstimate(pairs: pairs, parameters: parameters))
    #expect(abs(estimate.tauSeconds - 20 / 1_000_000) < 1e-9)
    #expect(estimate.acceptedPairs == 3)
}

@Test func stereoPairKeepsChannelsApart() {
    let pair = ChirpGenerator.stereoPair(parameters, sampleRate: sampleRate, amplitude: 0.5)
    let onset = Int(parameters.pairOnsetIntervalSeconds * sampleRate)
    #expect(pair.left[onset...].allSatisfy { $0 == 0 })
    #expect(pair.right[..<onset].allSatisfy { $0 == 0 })
}
