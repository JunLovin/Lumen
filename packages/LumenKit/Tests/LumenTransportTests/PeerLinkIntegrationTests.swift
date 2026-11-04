import Foundation
import LumenApplication
import LumenDomain
import LumenTransport
import Testing

/// Serialized so that only one test at a time depends on Bonjour discovery timing.
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
        let mac = MacSecureLink(version: version, sink: temporarySink(), serviceType: control)
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
            objectWidthMillimeters: 10, objectHeightMillimeters: 10, rotationRadians: 0, edge: .right
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
        let mac = MacSecureLink(version: version, sink: temporarySink(), serviceType: control)
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
        let mac = MacSecureLink(version: version, sink: temporarySink(), serviceType: control)
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

    @Test(.enabled(if: isLocalRun, "CI runners do not allow Bonjour"), .timeLimit(.minutes(1)))
    func aFileCrossesEncryptedWithItsHashVerified() async throws {
        let trust = try await paired(service: uniqueService())
        let control = uniqueService()
        let sink = temporarySink()
        let mac = MacSecureLink(version: version, sink: sink, serviceType: control)
        let phone = PhoneSecureLink(version: version, serviceType: control)
        await mac.activate(identity: trust.mac.identity, peer: trust.mac.peer)
        await phone.activate(identity: trust.phone.identity, peer: trust.phone.peer)
        _ = await first(in: phone.events) { $0 == .connected }

        let bytes = Data((0 ..< 3 * 1024 * 1024).map { UInt8(truncatingIfNeeded: $0) })
        let url = FileManager.default.temporaryDirectory.appending(path: "lumen-upload-\(UUID().uuidString).bin")
        try bytes.write(to: url)
        await sink.register(TransferOffer(transferID: 9, resources: [
            TransferResource(index: 0, fileName: "video.mov", byteCount: UInt64(bytes.count)),
        ]))
        try await phone.upload(fileAt: url, transferID: 9, resourceIndex: 0) { _ in }

        var delivered: String?
        for await update in sink.updates {
            if case let .completed(path, _) = update.stage {
                delivered = path
                break
            }
        }
        let path = try #require(delivered)
        #expect(try Data(contentsOf: URL(filePath: path)) == bytes)
        await phone.deactivate()
        await mac.deactivate()
    }
}
