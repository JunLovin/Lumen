import LumenApplication
import LumenDomain
import Testing

private struct FakeProtocolInfo: ProtocolInfoPort {
    let localProtocolVersion: ProtocolVersion
}

@Test func readsTheVersionFromThePort() {
    let version = ProtocolVersion(rawValue: 7)
    let readProtocolVersion = ReadProtocolVersion(protocolInfo: FakeProtocolInfo(localProtocolVersion: version))
    #expect(readProtocolVersion() == version)
}
