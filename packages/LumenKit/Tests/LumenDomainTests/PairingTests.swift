import LumenDomain
import Testing

@Test func patternUsesOneColorPerLeadingByte() {
    let pattern = VerificationPattern(hash: [0, 7, 13, 255, 99])
    #expect(pattern?.colorIndices == [0, 1, 1, 3])
}

@Test func patternNeedsEnoughBytes() {
    #expect(VerificationPattern(hash: [1, 2]) == nil)
}

@Test func nearbyRequiresTheSignalToHold() {
    var detector = NearbyDetector(minimumRSSI: -45, dwellNanoseconds: 1000)
    let result1 = detector.observe(rssi: -40, atNanoseconds: 0)
    #expect(!result1)
    let result2 = detector.observe(rssi: -40, atNanoseconds: 999)
    #expect(!result2)
    let result3 = detector.observe(rssi: -40, atNanoseconds: 1000)
    #expect(result3)
}

@Test func aWeakReadingRestartsTheDwell() {
    var detector = NearbyDetector(minimumRSSI: -45, dwellNanoseconds: 1000)
    _ = detector.observe(rssi: -40, atNanoseconds: 0)
    _ = detector.observe(rssi: -70, atNanoseconds: 500)
    let result4 = detector.observe(rssi: -40, atNanoseconds: 1000)
    #expect(!result4)
    let result5 = detector.observe(rssi: -40, atNanoseconds: 2000)
    #expect(result5)
}

@Test func backoffDoublesUpToTheMaximumAndResets() {
    var backoff = ReconnectBackoff(initialMilliseconds: 100, maximumMilliseconds: 350)
    let result6 = backoff.nextDelayMilliseconds()
    #expect(result6 == 100)
    let result7 = backoff.nextDelayMilliseconds()
    #expect(result7 == 200)
    let result8 = backoff.nextDelayMilliseconds()
    #expect(result8 == 350)
    backoff.reset()
    let result9 = backoff.nextDelayMilliseconds()
    #expect(result9 == 100)
}
