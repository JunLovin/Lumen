import CryptoKit
import Foundation
import LumenApplication
import LumenDomain

public struct IdentityFactoryAdapter: IdentityFactoryPort {
    private static let deviceIDBytes = 16

    public init() {}

    public func makeIdentity(name: String) -> LocalIdentity {
        let key = Curve25519.Signing.PrivateKey()
        var generator = SystemRandomNumberGenerator()
        let deviceID = (0 ..< Self.deviceIDBytes).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return LocalIdentity(
            deviceID: deviceID,
            name: name,
            signingPrivateKey: Array(key.rawRepresentation),
            signingPublicKey: Array(key.publicKey.rawRepresentation)
        )
    }
}
