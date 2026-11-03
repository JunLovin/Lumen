import CryptoKit
import Foundation
import LumenDomain
import LumenProtocol

struct PairingExchange {
    enum Role {
        case initiator
        case responder
    }

    private static let nonceBytes = 32

    let verificationPattern: VerificationPattern
    let pairingSecret: Data
    let peer: PairingPeerIdentity
    let confirmation: Data

    struct PairingPeerIdentity {
        let deviceID: [UInt8]
        let name: String
        let signingPublicKey: [UInt8]
    }

    static func run(role: Role, identity: LocalIdentity, channel: FramedConnection) async throws -> PairingExchange {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let nonce = Data((0 ..< nonceBytes).map { _ in UInt8.random(in: .min ... .max) })
        let keyMessage = message(.key(.with {
            $0.x25519Public = key.publicKey.rawRepresentation
            $0.nonce = nonce
        }))
        let remote = try await exchangeKeys(
            role: role,
            key: key,
            nonce: nonce,
            keyMessage: keyMessage,
            channel: channel
        )

        let remotePublic = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remote.x25519Public)
        let shared = try key.sharedSecretFromKeyAgreement(with: remotePublic)
        let (initiator, responder) = role == .initiator
            ? (key.publicKey.rawRepresentation + nonce, remote.x25519Public + remote.nonce)
            : (remote.x25519Public + remote.nonce, key.publicKey.rawRepresentation + nonce)
        let salt = Data(SHA256.hash(data: initiator + responder))
        let derive = { (label: String) in KeyDerivation.derive(from: shared, salt: salt, label: label) }

        let sendLabel = role == .initiator ? "pairing.seal.initiator" : "pairing.seal.responder"
        let receiveLabel = role == .initiator ? "pairing.seal.responder" : "pairing.seal.initiator"
        try await channel.send(sealed(identity: identity, key: derive(sendLabel)))
        let peer = try await opened(channel.receive(), key: derive(receiveLabel))

        guard let pattern = VerificationPattern(hash: Array(derive("pairing.pattern"))) else {
            throw ChannelError.invalidMessage
        }
        return PairingExchange(
            verificationPattern: pattern,
            pairingSecret: derive("pairing.secret"),
            peer: peer,
            confirmation: derive("pairing.confirmation")
        )
    }

    /// The initiator commits to its key first, so neither side can pick a key after seeing the
    /// other's to force a matching four-color pattern.
    private static func exchangeKeys(
        role: Role,
        key: Curve25519.KeyAgreement.PrivateKey,
        nonce: Data,
        keyMessage: Data,
        channel: FramedConnection
    ) async throws -> Lumen_PairingKey {
        switch role {
        case .initiator:
            let commitment = Data(SHA256.hash(data: key.publicKey.rawRepresentation + nonce))
            try await channel.send(message(.commit(.with { $0.commitment = commitment })))
            let remote = try await receiveKey(channel)
            try await channel.send(keyMessage)
            return remote
        case .responder:
            let first = try await channel.receive()
            guard case let .commit(commit) = try Lumen_PairingMessage(serializedBytes: first).message else {
                throw ChannelError.invalidMessage
            }
            try await channel.send(keyMessage)
            let remote = try await receiveKey(channel)
            guard Data(SHA256.hash(data: remote.x25519Public + remote.nonce)) == commit.commitment else {
                throw ChannelError.handshakeFailed
            }
            return remote
        }
    }

    private static func receiveKey(_ channel: FramedConnection) async throws -> Lumen_PairingKey {
        guard case let .key(key) = try await Lumen_PairingMessage(serializedBytes: channel.receive()).message else {
            throw ChannelError.invalidMessage
        }
        return key
    }

    private static func message(_ content: Lumen_PairingMessage.OneOf_Message) -> Data {
        var pairingMessage = Lumen_PairingMessage()
        pairingMessage.message = content
        return (try? pairingMessage.serializedData()) ?? Data()
    }

    private static func sealed(identity: LocalIdentity, key: Data) throws -> Data {
        let plain = try Lumen_PairingIdentity.with {
            $0.deviceID = Data(identity.deviceID)
            $0.signingPublic = Data(identity.signingPublicKey)
            $0.name = identity.name
        }.serializedData()
        let box = try ChaChaPoly.seal(plain, using: SymmetricKey(data: key)).combined
        return message(.sealed(.with { $0.sealedBox = box }))
    }

    private static func opened(_ data: Data, key: Data) throws -> PairingPeerIdentity {
        guard case let .sealed(sealed) = try Lumen_PairingMessage(serializedBytes: data).message else {
            throw ChannelError.invalidMessage
        }
        let box = try ChaChaPoly.SealedBox(combined: sealed.sealedBox)
        let plain = try ChaChaPoly.open(box, using: SymmetricKey(data: key))
        let peer = try Lumen_PairingIdentity(serializedBytes: plain)
        return PairingPeerIdentity(
            deviceID: Array(peer.deviceID),
            name: peer.name,
            signingPublicKey: Array(peer.signingPublic)
        )
    }

    func pairedDevice() -> PairedDevice {
        PairedDevice(
            deviceID: peer.deviceID,
            name: peer.name,
            signingPublicKey: peer.signingPublicKey,
            pairingSecret: Array(pairingSecret)
        )
    }

    static func confirmedMessage(_ confirmation: Data) -> Data {
        message(.confirmed(.with { $0.confirmation = confirmation }))
    }

    static func isConfirmed(_ data: Data, expected: Data) -> Bool {
        guard case let .confirmed(confirmed) = try? Lumen_PairingMessage(serializedBytes: data).message else {
            return false
        }
        return confirmed.confirmation == expected
    }
}
