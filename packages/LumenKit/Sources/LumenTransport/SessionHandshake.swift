import CryptoKit
import Foundation
import LumenDomain
import LumenProtocol

struct SessionSecrets {
    let realtimePSK: Data
    let filePSK: Data
}

enum SessionHandshake {
    enum Role: String {
        case initiator
        case responder
    }

    static func run(
        role: Role,
        identity: LocalIdentity,
        peer: PairedDevice,
        version: ProtocolVersion,
        channel: FramedConnection
    ) async throws -> SessionSecrets {
        try await exchangeHello(role: role, version: version, channel: channel)
        let key = Curve25519.KeyAgreement.PrivateKey()
        let signing = try Curve25519.Signing.PrivateKey(rawRepresentation: identity.signingPrivateKey)
        let publicKey = key.publicKey.rawRepresentation
        let outgoing = try sessionKey(publicKey, signature: signing.signature(for: signed(publicKey, role: role)))

        if role == .initiator {
            try await channel.send(outgoing)
        }
        let remote = try await receiveSessionKey(channel)
        if role == .responder {
            try await channel.send(outgoing)
        }

        let remoteRole: Role = role == .initiator ? .responder : .initiator
        let verifier = try Curve25519.Signing.PublicKey(rawRepresentation: peer.signingPublicKey)
        guard verifier.isValidSignature(remote.signature, for: signed(remote.x25519Public, role: remoteRole)) else {
            throw ChannelError.handshakeFailed
        }
        let shared = try key.sharedSecretFromKeyAgreement(
            with: Curve25519.KeyAgreement.PublicKey(rawRepresentation: remote.x25519Public)
        )
        let salt = Data(peer.pairingSecret)
        return SessionSecrets(
            realtimePSK: KeyDerivation.derive(from: shared, salt: salt, label: "realtime"),
            filePSK: KeyDerivation.derive(from: shared, salt: salt, label: "file")
        )
    }

    private static func exchangeHello(role: Role, version: ProtocolVersion, channel: FramedConnection) async throws {
        var hello = Lumen_ControlMessage()
        hello.message = .hello(.with { $0.protocolVersion = .init(rawValue: Int(version.rawValue)) ?? .unspecified })
        let outgoing = try hello.serializedData()
        if role == .initiator {
            try await channel.send(outgoing)
        }
        let incoming = try await Lumen_ControlMessage(serializedBytes: channel.receive()).message
        switch incoming {
        case let .hello(remote) where Int32(remote.protocolVersion.rawValue) == version.rawValue:
            if role == .responder {
                try await channel.send(outgoing)
            }
        case .hello where role == .responder:
            var rejection = Lumen_ControlMessage()
            rejection.message = .incompatibleVersion(.with {
                $0.supported = .init(rawValue: Int(version.rawValue)) ?? .unspecified
            })
            try await channel.send(rejection.serializedData())
            throw ChannelError.incompatible
        case .incompatibleVersion, .hello:
            throw ChannelError.incompatible
        default:
            throw ChannelError.invalidMessage
        }
    }

    private static func signed(_ publicKey: Data, role: Role) -> Data {
        Data("lumen.session.\(role.rawValue)".utf8) + publicKey
    }

    private static func sessionKey(_ publicKey: Data, signature: Data) throws -> Data {
        var message = Lumen_ControlMessage()
        message.message = .sessionKey(.with {
            $0.x25519Public = publicKey
            $0.signature = signature
        })
        return try message.serializedData()
    }

    private static func receiveSessionKey(_ channel: FramedConnection) async throws -> Lumen_SessionKey {
        let message = try await Lumen_ControlMessage(serializedBytes: channel.receive()).message
        guard case let .sessionKey(key) = message else { throw ChannelError.invalidMessage }
        return key
    }
}
