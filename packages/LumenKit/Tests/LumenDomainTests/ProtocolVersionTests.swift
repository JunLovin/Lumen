import LumenDomain
import Testing

@Test func negotiationSucceedsWithTheSameVersion() {
    let version = ProtocolVersion(rawValue: 1)
    #expect(version.negotiate(with: version) == .success(version))
}

@Test func negotiationReportsBothVersionsOnMismatch() {
    let local = ProtocolVersion(rawValue: 1)
    let remote = ProtocolVersion(rawValue: 2)
    #expect(local.negotiate(with: remote) == .failure(ProtocolVersionMismatch(local: local, remote: remote)))
}
