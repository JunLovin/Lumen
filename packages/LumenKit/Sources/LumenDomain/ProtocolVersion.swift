public struct ProtocolVersion: Sendable, Equatable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public func negotiate(with remote: ProtocolVersion) -> Result<ProtocolVersion, ProtocolVersionMismatch> {
        self == remote ? .success(self) : .failure(ProtocolVersionMismatch(local: self, remote: remote))
    }
}

public struct ProtocolVersionMismatch: Error, Equatable {
    public let local: ProtocolVersion
    public let remote: ProtocolVersion

    public init(local: ProtocolVersion, remote: ProtocolVersion) {
        self.local = local
        self.remote = remote
    }
}
