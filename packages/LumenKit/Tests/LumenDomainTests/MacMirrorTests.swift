import LumenDomain
import Testing

private let space = MacSpace(widthPoints: 1000, heightPoints: 600, pointsPerMillimeter: 4, entryStripFraction: 0.5)

private func sample(x: Float, velocityX: Float = 0, sequence: UInt32 = 1) -> DragFrameSample {
    DragFrameSample(
        session: 1,
        sequence: sequence,
        timestampNs: 0,
        xMillimeters: x,
        yMillimeters: 50,
        velocityXMillimetersPerSecond: velocityX,
        velocityYMillimetersPerSecond: 0,
        edgeProximity: 1,
        objectWidthMillimeters: 20,
        objectHeightMillimeters: 20,
        rotationRadians: 0,
        edge: .right
    )
}

@Test func anObjectKeepsItsPhysicalSizeOnTheMac() {
    #expect(space.size(millimeters: 20) == 80)
}

@Test func crossingThePhonesRightEdgeEntersTheMacsLeftEdge() {
    let point = space.point(worldX: 5, worldY: 75, phoneHeightMillimeters: 150, edge: .right)
    #expect(point.x == 20)
    #expect(point.y == 300)
}

@Test func crossingThePhonesLeftEdgeEntersTheMacsRightEdge() {
    #expect(space.point(worldX: 5, worldY: 0, phoneHeightMillimeters: 150, edge: .left).x == 980)
}

@Test func heightStaysInsideTheEntryStrip() {
    #expect(space.point(worldX: 0, worldY: 0, phoneHeightMillimeters: 150, edge: .right).y == 150)
    #expect(space.point(worldX: 0, worldY: 150, phoneHeightMillimeters: 150, edge: .right).y == 450)
}

@Test func theGhostCondensesAsItEnters() {
    let frame = { (worldX: Double) in
        InterpolatedFrame(
            worldX: worldX, worldY: 0, velocityX: 0, velocityY: 0, edgeProximity: 1,
            rotation: 0, objectWidth: 20, edge: .right
        )
    }
    #expect(space.ghostPose(for: frame(-10), phoneHeightMillimeters: 150).condensation == 0)
    #expect(space.ghostPose(for: frame(0), phoneHeightMillimeters: 150).condensation == 0.5)
    #expect(space.ghostPose(for: frame(10), phoneHeightMillimeters: 150).condensation == 1)
}

@Test func interpolatesBetweenTwoFrames() {
    var interpolator = FrameInterpolator(maximumExtrapolationNanoseconds: 100)
    interpolator.add(TimedDragFrame(sample: sample(x: 0), localTimestampNs: 100))
    interpolator.add(TimedDragFrame(sample: sample(x: 10), localTimestampNs: 200))
    #expect(interpolator.frame(atNanoseconds: 150)?.worldX == 5)
}

@Test func acceptsFramesArrivingOutOfOrder() {
    var interpolator = FrameInterpolator(maximumExtrapolationNanoseconds: 100)
    interpolator.add(TimedDragFrame(sample: sample(x: 10), localTimestampNs: 200))
    interpolator.add(TimedDragFrame(sample: sample(x: 0), localTimestampNs: 100))
    #expect(interpolator.frame(atNanoseconds: 150)?.worldX == 5)
}

@Test func extrapolatesWithVelocityUpToALimit() {
    var interpolator = FrameInterpolator(maximumExtrapolationNanoseconds: 100_000_000)
    interpolator.add(TimedDragFrame(sample: sample(x: 0, velocityX: 100), localTimestampNs: 0))
    #expect(interpolator.frame(atNanoseconds: 50_000_000)?.worldX == 5)
    #expect(interpolator.frame(atNanoseconds: 900_000_000)?.worldX == 10)
}

@Test func anEmptyInterpolatorHasNoFrame() {
    #expect(FrameInterpolator(maximumExtrapolationNanoseconds: 1).frame(atNanoseconds: 0) == nil)
}

@Test func aSpringSettlesOnItsTargetWhileKeepingInheritedVelocity() {
    var value = SpringValue(position: 0, velocity: 500)
    let parameters = SpringParameters(response: 0.5, damping: 0.72)
    value.advance(toward: 100, parameters: parameters, seconds: 0.05)
    #expect(value.position > 15)
    value.advance(toward: 100, parameters: parameters, seconds: 5)
    #expect(value.isSettled(at: 100, tolerance: 0.01))
}

@Test func aLandingReachesItsTargetFullyCondensed() {
    let pose = GhostPose(center: MacPoint(x: 0, y: 0), size: 80, rotation: 0, condensation: 0.4)
    var landing = GhostLanding(
        from: pose,
        velocity: MacPoint(x: 300, y: 0),
        target: MacPoint(x: 100, y: 200),
        parameters: SpringParameters(response: 0.5, damping: 0.72)
    )
    var last = pose
    for _ in 0 ..< 300 {
        last = landing.advance(seconds: 1.0 / 60)
    }
    #expect(landing.isSettled)
    #expect(abs(last.condensation - 1) < 0.01)
}
