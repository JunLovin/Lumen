import Foundation
import LumenApplication
import LumenDomain
import LumenTransport
import Testing

/// Serialized: several tests advertising Bonjour services at once hang on discovery, while
/// serial runs pass every time.
@Suite(.serialized)
struct PeerLinkIntegrationTests {
    @Test(.enabled(if: isLocalRun, "CI runners do not allow Bonjour"), .timeLimit(.minutes(1)))
    func pairingAgreesOnSecretAndPattern() async throws {
        let result = try await paired(service: uniqueService())
        #expect(result.patterns[0] == result.patterns[1])
        #expect(result.mac.peer.pairingSecret == result.phone.peer.pairingSecret)
        #expect(result.mac.peer.name == "iPhone")
        #expect(result.phone.peer.name == "Mac")
        #expect(result.mac.peer.signingPublicKey == result.phone.identity.signingPublicKey)
    }

    @Test(.enabled(if: isLocalRun, "CI runners do not allow Bonjour"), .timeLimit(.minutes(1)))
    func encryptedChannelsCarryEveryMessageKind() async throws {
        let service = uniqueService()
        let trust = try await paired(service: service)
        let control = uniqueService()
        let mac = MacSecureLink(version: version, serviceType: control)
        let phone = PhoneSecureLink(version: version, serviceType: control)
        await mac.activate(identity: trust.mac.identity, peer: trust.mac.peer)
        await phone.activate(identity: trust.phone.identity, peer: trust.phone.peer)

        let macEvents = mac.events
        _ = await first(in: phone.events) { $0 == .connected }
        _ = await first(in: macEvents) { $0 == .connected }

        await phone.send(.playChirpPair(requestID: 5))
        let control2 = await first(in: macEvents) {
            if case .received(.playChirpPair) = $0 {
                true
            } else {
                false
            }
        }
        #expect(control2 == .received(.playChirpPair(requestID: 5)))

        let frame = DragFrameSample(
            session: 1, sequence: 1, timestampNs: 9, xMillimeters: 1, yMillimeters: 2,
            velocityXMillimetersPerSecond: 0, velocityYMillimetersPerSecond: 0, edgeProximity: 0.5,
            objectWidthMillimeters: 10, objectHeightMillimeters: 10, rotationRadians: 0
        )
        await phone.send(.dragFrame(frame))
        let received = await first(in: macEvents) {
            if case .received(.dragFrame) = $0 {
                true
            } else {
                false
            }
        }
        #expect(received == .received(.dragFrame(frame)))

        await mac.send(.clockPing(originNs: 3))
        let ping = await first(in: phone.events) {
            if case .received(.clockPing) = $0 {
                true
            } else {
                false
            }
        }
        #expect(ping == .received(.clockPing(originNs: 3)))

        #expect(await phone.probeFileChannel())
        await phone.deactivate()
        await mac.deactivate()
    }

    @Test(.enabled(if: isLocalRun, "CI runners do not allow Bonjour"), .timeLimit(.minutes(1)))
    func theWrongSecretNeverConnects() async throws {
        let trust = try await paired(service: uniqueService())
        let control = uniqueService()
        let mac = MacSecureLink(version: version, serviceType: control)
        let impostor = PhoneSecureLink(version: version, serviceType: control)
        let forged = PairedDevice(
            deviceID: trust.phone.peer.deviceID,
            name: trust.phone.peer.name,
            signingPublicKey: trust.phone.peer.signingPublicKey,
            pairingSecret: [UInt8](repeating: 1, count: 32)
        )
        await mac.activate(identity: trust.mac.identity, peer: trust.mac.peer)
        await impostor.activate(identity: trust.phone.identity, peer: forged)
        let outcome = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await first(in: mac.events) { $0 == .connected } != nil }
            group.addTask {
                try? await Task.sleep(for: .seconds(4))
                return false
            }
            defer { group.cancelAll() }
            return await group.next() ?? false
        }
        #expect(!outcome)
        await impostor.deactivate()
        await mac.deactivate()
    }

    @Test(.enabled(if: isLocalRun, "CI runners do not allow Bonjour"), .timeLimit(.minutes(1)))
    func aPhoneReconnectsAfterTheControlChannelDrops() async throws {
        let trust = try await paired(service: uniqueService())
        let control = uniqueService()
        let mac = MacSecureLink(version: version, serviceType: control)
        let phone = PhoneSecureLink(version: version, serviceType: control)
        await mac.activate(identity: trust.mac.identity, peer: trust.mac.peer)
        await phone.activate(identity: trust.phone.identity, peer: trust.phone.peer)
        let events = phone.events
        _ = await first(in: events) { $0 == .connected }

        let clock = ContinuousClock()
        await mac.dropSessionForTesting()
        _ = await first(in: events) { $0 == .disconnected }
        let elapsed = await clock.measure {
            _ = await first(in: events) { $0 == .connected }
        }
        #expect(elapsed < .seconds(2))
        await phone.deactivate()
        await mac.deactivate()
    }
}
