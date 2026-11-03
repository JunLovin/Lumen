import LumenApplication
import LumenDomain
import LumenProtocol

public struct ProtocolInfoAdapter: ProtocolInfoPort {
    public init() {}

    public var localProtocolVersion: ProtocolVersion {
        ProtocolVersion(rawValue: Int32(Lumen_ProtocolVersion.current.rawValue))
    }
}
