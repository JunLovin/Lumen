import Foundation
import LumenProtocol
import Testing

private let fixturesDirectory = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .appending(path: "../../../../fixtures/protocol")
    .standardized

@Test func helloFixtureRoundTrips() throws {
    let bytes = try Data(contentsOf: fixturesDirectory.appending(path: "hello.bin"))
    let hello = try Lumen_Hello(serializedBytes: bytes)

    #expect(hello.protocolVersion == .current)
    #expect(hello.deviceIDHash == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    #expect(try hello.serializedData() == bytes)
}
