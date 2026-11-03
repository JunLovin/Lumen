import Foundation
import LumenTransport

@objc(LumenKitBridge)
public final class LumenKitBridge: NSObject {
    @objc public static func protocolVersion() -> Int32 {
        ProtocolInfoAdapter().localProtocolVersion.rawValue
    }
}
