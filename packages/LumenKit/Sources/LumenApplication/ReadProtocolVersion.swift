import LumenDomain

public struct ReadProtocolVersion: Sendable {
    private let protocolInfo: any ProtocolInfoPort

    public init(protocolInfo: any ProtocolInfoPort) {
        self.protocolInfo = protocolInfo
    }

    public func callAsFunction() -> ProtocolVersion {
        protocolInfo.localProtocolVersion
    }
}
