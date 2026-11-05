import LumenDomain

public protocol ProtocolInfoPort: Sendable {
    var localProtocolVersion: ProtocolVersion { get }
}
