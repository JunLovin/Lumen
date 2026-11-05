import Foundation
import LumenApplication
import LumenDomain
import LumenTransport
import Testing

private func firstMessage(
    in events: AsyncStream<PeerEvent>,
    matching predicate: @Sendable @escaping (PeerMessage) -> Bool
) async -> PeerMessage? {
    for await event in events {
        if case let .received(message) = event, predicate(message) {
            return message
        }
    }
    return nil
}

@Test(
    .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil, "CI runners do not allow Bonjour"),
    .timeLimit(.minutes(1))
)
func peersFindEachOtherAndExchangeDatagrams() async {
    let serviceType = "_lumentest._udp"
    let mac = MacPeerLink(serviceType: serviceType)
    let phone = PhonePeerLink(protocolVersion: ProtocolVersion(rawValue: 1), serviceType: serviceType)
    #expect(await mac.start())
    #expect(await phone.start())

    let hello = await firstMessage(in: mac.events) {
        if case .hello = $0 {
            true
        } else {
            false
        }
    }
    #expect(hello == .hello(ProtocolVersion(rawValue: 1)))

    await mac.send(.playChirpPair(requestID: 5))
    let request = await firstMessage(in: phone.events) {
        if case .playChirpPair = $0 {
            true
        } else {
            false
        }
    }
    #expect(request == .playChirpPair(requestID: 5))
}
