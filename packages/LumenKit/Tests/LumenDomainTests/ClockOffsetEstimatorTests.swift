import LumenDomain
import Testing

@Test func estimatesOffsetWithSymmetricDelay() {
    let sample = ClockSample(originNs: 1000, remoteReceiveNs: 5100, remoteTransmitNs: 5200, destinationNs: 1300)
    #expect(sample.remoteAheadNanoseconds == 4000)
    #expect(sample.roundTripNanoseconds == 200)
}

@Test func keepsTheSampleWithTheShortestRoundTrip() {
    var estimator = ClockOffsetEstimator()
    estimator.add(ClockSample(originNs: 0, remoteReceiveNs: 9000, remoteTransmitNs: 9000, destinationNs: 2000))
    estimator.add(ClockSample(originNs: 3000, remoteReceiveNs: 7050, remoteTransmitNs: 7050, destinationNs: 3100))
    #expect(estimator.bestSample?.roundTripNanoseconds == 100)
    #expect(estimator.localTimestamp(fromRemote: 14000) == 10000)
}

@Test func hasNoLocalTimestampBeforeAnySample() {
    #expect(ClockOffsetEstimator().localTimestamp(fromRemote: 1) == nil)
}

@Test func percentilesUseOnlyTheNewestValues() {
    var window = SampleWindow(capacity: 3)
    for value in [100.0, 1, 2, 3] {
        window.add(value)
    }
    #expect(window.count == 3)
    #expect(window.percentile(1) == 3)
    #expect(window.percentile(0) == 1)
}

@Test func anEmptyWindowHasNoPercentile() {
    #expect(SampleWindow(capacity: 3).percentile(0.5) == nil)
}
