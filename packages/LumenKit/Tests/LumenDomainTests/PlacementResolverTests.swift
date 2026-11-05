import LumenDomain
import Testing

private let minute: UInt64 = 60_000_000_000

@Test func aClearAcousticReadingGivesHighConfidence() {
    var resolver = PlacementResolver()
    resolver.apply(.acoustic(tauMicroseconds: 230, levelDifferenceDecibels: 14, snrDecibels: 40), atNanoseconds: 0)
    let placement = resolver.placement(atNanoseconds: 0)
    #expect(placement.side == .left)
    #expect(placement.confidence >= 0.8)
}

@Test func negativeTauMeansTheRightSide() {
    var resolver = PlacementResolver()
    resolver.apply(.acoustic(tauMicroseconds: -220, levelDifferenceDecibels: -9, snrDecibels: 40), atNanoseconds: 0)
    #expect(resolver.placement(atNanoseconds: 0).side == .right)
}

@Test func disagreeingSignalsStayBelowTheHighConfidenceBand() {
    var resolver = PlacementResolver()
    resolver.apply(.acoustic(tauMicroseconds: 230, levelDifferenceDecibels: -9, snrDecibels: 40), atNanoseconds: 0)
    #expect(resolver.placement(atNanoseconds: 0).confidence < 0.8)
}

@Test func aWeakSignalChangesNothing() {
    var resolver = PlacementResolver()
    resolver.apply(.acoustic(tauMicroseconds: 230, levelDifferenceDecibels: 14, snrDecibels: 5), atNanoseconds: 0)
    #expect(resolver.placement(atNanoseconds: 0).side == .unknown)
}

@Test func anEdgeExitOutweighsAnOlderAcousticReading() {
    var resolver = PlacementResolver()
    resolver.apply(.acoustic(tauMicroseconds: 230, levelDifferenceDecibels: 14, snrDecibels: 40), atNanoseconds: 0)
    resolver.apply(.edgeExit(.left), atNanoseconds: 1)
    resolver.apply(.edgeExit(.left), atNanoseconds: 2)
    #expect(resolver.placement(atNanoseconds: 2).side == .right)
}

@Test func movingResetsTowardUncertainty() {
    var resolver = PlacementResolver()
    resolver.apply(.edgeExit(.right), atNanoseconds: 0)
    resolver.apply(.moved, atNanoseconds: 1)
    #expect(resolver.placement(atNanoseconds: 1).confidence < 0.5)
}

@Test func aFreshReadingAfterMovingReachesHighConfidenceOnTheNewSide() {
    var resolver = PlacementResolver()
    resolver.apply(.edgeExit(.right), atNanoseconds: 0)
    resolver.apply(.moved, atNanoseconds: 1)
    resolver.apply(.acoustic(tauMicroseconds: -220, levelDifferenceDecibels: -9, snrDecibels: 40), atNanoseconds: 2)
    let placement = resolver.placement(atNanoseconds: 2)
    #expect(placement.side == .right)
    #expect(placement.confidence >= 0.8)
}

@Test func confidenceDecaysWithTime() {
    var resolver = PlacementResolver()
    resolver.apply(.edgeExit(.right), atNanoseconds: 0)
    let fresh = resolver.placement(atNanoseconds: 0).confidence
    let stale = resolver.placement(atNanoseconds: 30 * minute).confidence
    #expect(stale < fresh)
}

@Test func aDetachedPhoneHasNoSide() {
    var resolver = PlacementResolver()
    resolver.apply(.edgeExit(.right), atNanoseconds: 0)
    resolver.setDetached(true)
    #expect(resolver.placement(atNanoseconds: 0).side == .unknown)
}

@Test func anyEvidenceSequenceKeepsAValidDistribution() {
    var generator = SystemRandomNumberGenerator()
    for _ in 0 ..< 200 {
        var resolver = PlacementResolver()
        var now: UInt64 = 0
        for _ in 0 ..< 50 {
            now += UInt64.random(in: 0 ... 10 * minute, using: &generator)
            resolver.apply(randomEvidence(using: &generator), atNanoseconds: now)
            let probabilities = resolver.placement(atNanoseconds: now).distribution.probabilities
            #expect(probabilities.allSatisfy { $0 >= 0 && $0 <= 1 })
            #expect(abs(probabilities.reduce(0, +) - 1) < 1e-9)
        }
    }
}

private func randomEvidence(using generator: inout SystemRandomNumberGenerator) -> PlacementEvidence {
    switch Int.random(in: 0 ... 2, using: &generator) {
    case 0:
        .acoustic(
            tauMicroseconds: Float.random(in: -1000 ... 1000, using: &generator),
            levelDifferenceDecibels: Float.random(in: -30 ... 30, using: &generator),
            snrDecibels: Float.random(in: 0 ... 60, using: &generator)
        )
    case 1:
        .edgeExit(PhoneEdge.allCases.randomElement(using: &generator) ?? .top)
    default:
        .moved
    }
}

@Test func theEdgeFacingTheMacFollowsClockwiseRotation() {
    #expect(PhoneEdge.right.rotated(clockwiseQuarterTurns: 1) == .top)
    #expect(PhoneEdge.top.rotated(clockwiseQuarterTurns: 1) == .left)
    #expect(PhoneEdge.right.rotated(clockwiseQuarterTurns: -1) == .bottom)
    #expect(PhoneEdge.right.rotated(clockwiseQuarterTurns: 4) == .right)
}

@Test func aPhoneOnTheLeftFacesTheMacWithItsRightEdge() {
    #expect(PhoneEdge.facingMac(from: .left) == .right)
    #expect(PhoneEdge.facingMac(from: .unknown) == nil)
}

@Test func settlingRequiresMovementThenQuiet() {
    var detector = MotionSettleDetector(movingAcceleration: 0.1, quietNanoseconds: 1000)
    let quietBeforeMoving = detector.observe(acceleration: 0, atNanoseconds: 0)
    _ = detector.observe(acceleration: 0.5, atNanoseconds: 100)
    let tooSoon = detector.observe(acceleration: 0, atNanoseconds: 200)
    let settled = detector.observe(acceleration: 0, atNanoseconds: 1200)
    let once = detector.observe(acceleration: 0, atNanoseconds: 3000)
    #expect(!quietBeforeMoving)
    #expect(!tooSoon)
    #expect(settled)
    #expect(!once)
}

@Test func detachmentNeedsSeveralReadingsBothWays() {
    var detector = DetachmentDetector(farRSSI: -75, nearRSSI: -65, requiredReadings: 2)
    let first = detector.observe(rssi: -80)
    let second = detector.observe(rssi: -80)
    let stillFar = detector.observe(rssi: -70)
    _ = detector.observe(rssi: -60)
    let back = detector.observe(rssi: -60)
    #expect(!first)
    #expect(second)
    #expect(stillFar)
    #expect(!back)
}
