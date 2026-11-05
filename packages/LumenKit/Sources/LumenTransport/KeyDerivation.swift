import CryptoKit
import Foundation

enum KeyDerivation {
    private static let keyBytes = 32

    static func derive(from secret: SymmetricKey, salt: Data, label: String) -> Data {
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: secret,
            salt: salt,
            info: Data("lumen.\(label)".utf8),
            outputByteCount: keyBytes
        )
        return key.withUnsafeBytes { Data($0) }
    }

    static func derive(from secret: SharedSecret, salt: Data, label: String) -> Data {
        let key = secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: Data("lumen.\(label)".utf8),
            outputByteCount: keyBytes
        )
        return key.withUnsafeBytes { Data($0) }
    }

    static func controlPSK(pairingSecret: [UInt8]) -> Data {
        derive(from: SymmetricKey(data: pairingSecret), salt: Data(), label: "control")
    }

    static func serviceIdentifier(deviceID: [UInt8]) -> String {
        SHA256.hash(data: Data(deviceID)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
