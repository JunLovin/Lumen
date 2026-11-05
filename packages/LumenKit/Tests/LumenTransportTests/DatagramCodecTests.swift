import Foundation
import LumenApplication
import LumenDomain
import LumenTransport
import Testing

private let fixturesDirectory = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .appending(path: "../../../../fixtures/protocol")
    .standardized

private func fixture(_ name: String) throws -> Data {
    try Data(contentsOf: fixturesDirectory.appending(path: "\(name).bin"))
}

private let dragFrame = DragFrameSample(
    session: 7,
    sequence: 42,
    timestampNs: 123_456_789,
    xMillimeters: 12.5,
    yMillimeters: -3.25,
    velocityXMillimetersPerSecond: 100.5,
    velocityYMillimetersPerSecond: -50.25,
    edgeProximity: 0.75,
    objectWidthMillimeters: 40,
    objectHeightMillimeters: 30,
    rotationRadians: 0.5,
    edge: .right
)

@Test(arguments: [
    ("control-drag-began", PeerMessage.dragBegan(DragStart(
        session: 7,
        thumbnailJPEG: [1, 2],
        phoneHeightMillimeters: 150.5
    ))),
    ("control-drag-ended", PeerMessage.dragEnded(DragEnd(
        session: 7,
        crossed: true,
        velocityXMillimetersPerSecond: 100.5,
        velocityYMillimetersPerSecond: -50.25
    ))),
    ("control-landed", PeerMessage.landed(session: 7)),
    ("control-transfer-offer", PeerMessage.transferOffer(TransferOffer(
        transferID: 7,
        resources: [TransferResource(index: 0, fileName: "IMG_0001.HEIC", byteCount: 4096)]
    ))),
    ("control-transfer-cancel", PeerMessage.transferCancel(transferID: 7)),
    ("control-transfer-preparing", PeerMessage.transferPreparing(transferID: 7, fraction: 0.5)),
    ("control-motion-settled", PeerMessage.motionSettled),
    ("control-begin-locate", PeerMessage.beginLocate),
    ("control-edge-exit", PeerMessage.edgeExit(.right)),
    ("control-placement-update", PeerMessage.placementUpdate(Placement(
        side: .right,
        confidence: 0.75,
        distribution: PlacementDistribution(probabilities: [0.0625, 0.75, 0.0625, 0.0625, 0.0625]),
        isDetached: false
    ))),
    ("control-clock-ping", PeerMessage.clockPing(originNs: 1000)),
    ("control-clock-pong", PeerMessage.clockPong(originNs: 1000, receiveNs: 2000, transmitNs: 3000)),
    ("control-play-chirp-pair", PeerMessage.playChirpPair(requestID: 9)),
    ("control-acoustic-report", PeerMessage.acousticReport(AcousticReading(
        requestID: 9,
        tauMicroseconds: -640.5,
        levelDifferenceDecibels: -3.5,
        snrDecibels: 18.25,
        acceptedPairs: 3
    ))),
])
func controlFixtureRoundTrips(name: String, message: PeerMessage) throws {
    let bytes = try fixture(name)
    #expect(WireCodec.decodeControl(bytes) == message)
    #expect(WireCodec.encodeControl(message) == bytes)
}

@Test func dragFrameFixtureRoundTrips() throws {
    let bytes = try fixture("datagram-drag-frame")
    #expect(WireCodec.decodeDatagram(bytes) == .dragFrame(dragFrame))
    #expect(WireCodec.encodeDatagram(dragFrame) == bytes)
}

@Test func helloFixtureCarriesTheCurrentVersion() throws {
    #expect(try WireCodec.decodeDatagram(fixture("datagram-hello")) == .hello(ProtocolVersion(rawValue: 1)))
}

@Test func garbageDecodesToNothing() {
    #expect(WireCodec.decodeDatagram(Data([0xFF, 0xFF, 0xFF])) == nil)
    #expect(WireCodec.decodeControl(Data([0xFF, 0xFF, 0xFF])) == nil)
}
