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
    rotationRadians: 0.5
)

@Test(arguments: [
    ("datagram-clock-ping", PeerMessage.clockPing(originNs: 1000)),
    ("datagram-clock-pong", PeerMessage.clockPong(originNs: 1000, receiveNs: 2000, transmitNs: 3000)),
    ("datagram-drag-frame", PeerMessage.dragFrame(dragFrame)),
    ("datagram-play-chirp-pair", PeerMessage.playChirpPair(requestID: 9)),
    ("datagram-acoustic-report", PeerMessage.acousticReport(AcousticReading(
        requestID: 9,
        tauMicroseconds: -640.5,
        levelDifferenceDecibels: -3.5,
        snrDecibels: 18.25,
        acceptedPairs: 3
    ))),
])
func fixtureRoundTrips(name: String, message: PeerMessage) throws {
    let bytes = try fixture(name)
    #expect(DatagramCodec.decode(bytes) == message)
    #expect(DatagramCodec.encode(message) == bytes)
}

@Test func helloFixtureCarriesTheCurrentVersion() throws {
    #expect(try DatagramCodec.decode(fixture("datagram-hello")) == .hello(ProtocolVersion(rawValue: 1)))
}

@Test func garbageDecodesToNothing() {
    #expect(DatagramCodec.decode(Data([0xFF, 0xFF, 0xFF])) == nil)
}
