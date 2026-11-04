import Foundation
import LumenApplication
import LumenDomain
import LumenTransport
import Testing

let version = ProtocolVersion(rawValue: 1)
let isLocalRun = ProcessInfo.processInfo.environment["CI"] == nil

func uniqueService() -> String {
    let suffix = String(UInt32.random(in: .min ... .max), radix: 36)
    return "_lt\(suffix)._tcp"
}

func first<Element: Sendable>(
    in stream: AsyncStream<Element>,
    where predicate: @Sendable (Element) -> Bool
) async -> Element? {
    for await element in stream where predicate(element) {
        return element
    }
    return nil
}

func paired(service: String) async throws -> PairingResult {
    let factory = IdentityFactoryAdapter()
    let macIdentity = factory.makeIdentity(name: "Mac")
    let phoneIdentity = factory.makeIdentity(name: "iPhone")
    let responder = PairingResponder(serviceType: service)
    let initiator = PairingInitiator(serviceType: service)
    let macStages = await responder.begin(identity: macIdentity)
    let phoneStages = await initiator.begin(identity: phoneIdentity)

    let macPattern = await first(in: macStages) {
        if case .awaitingConfirmation = $0 {
            true
        } else {
            false
        }
    }
    let phonePattern = await first(in: phoneStages) {
        if case .awaitingConfirmation = $0 {
            true
        } else {
            false
        }
    }
    guard
        case let .awaitingConfirmation(macColors)? = macPattern,
        case let .awaitingConfirmation(phoneColors)? = phonePattern
    else { throw ChannelError.handshakeFailed }

    await responder.confirm()
    let macDone = await first(in: macStages) {
        if case .paired = $0 {
            true
        } else {
            false
        }
    }
    let phoneDone = await first(in: phoneStages) {
        if case .paired = $0 {
            true
        } else {
            false
        }
    }
    guard case let .paired(macPeer)? = macDone, case let .paired(phonePeer)? = phoneDone else {
        throw ChannelError.handshakeFailed
    }
    return PairingResult(
        mac: Trust(identity: macIdentity, peer: macPeer),
        phone: Trust(identity: phoneIdentity, peer: phonePeer),
        patterns: [macColors, phoneColors]
    )
}

struct PairingResult {
    let mac: Trust
    let phone: Trust
    let patterns: [VerificationPattern]
}

struct Trust {
    let identity: LocalIdentity
    let peer: PairedDevice
}

func temporarySink() -> TemporaryFileSink {
    TemporaryFileSink(root: FileManager.default.temporaryDirectory.appending(path: "lumen-tests-\(UUID().uuidString)"))
}
