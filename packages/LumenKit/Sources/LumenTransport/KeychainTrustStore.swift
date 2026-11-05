import Foundation
import LumenApplication
import LumenDomain
import Security

public struct KeychainTrustStore: TrustStorePort {
    private static let identityAccount = "identity"
    private static let peerAccount = "peer"
    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func loadIdentity() async -> LocalIdentity? {
        load(account: Self.identityAccount)
    }

    public func save(identity: LocalIdentity) async -> Bool {
        save(identity, account: Self.identityAccount)
    }

    public func loadPeer() async -> PairedDevice? {
        load(account: Self.peerAccount)
    }

    public func save(peer: PairedDevice) async -> Bool {
        save(peer, account: Self.peerAccount)
    }

    public func forgetPeer() async {
        SecItemDelete(query(account: Self.peerAccount) as CFDictionary)
    }

    private func query(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    private func load<Value: Decodable>(account: String) -> Value? {
        var request = query(account: account)
        request[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard
            SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private func save(_ value: some Encodable, account: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        SecItemDelete(query(account: account) as CFDictionary)
        var request = query(account: account)
        request[kSecValueData as String] = data
        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(request as CFDictionary, nil) == errSecSuccess
    }
}
