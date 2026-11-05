import Foundation
import LumenApplication
import LumenDomain
import LumenProtocol
import Network

public actor PhoneSecureLink: SecureLinkPort {
    public nonisolated let events: AsyncStream<PeerEvent>
    private let continuation: AsyncStream<PeerEvent>.Continuation
    private let serviceType: String
    private let version: ProtocolVersion
    private var trust: (identity: LocalIdentity, peer: PairedDevice)?
    private var browser: NWBrowser?
    private var control: FramedConnection?
    private var realtime: NWConnection?
    var fileEndpoint: NWEndpoint?
    var filePSK: Data?
    private var lastHost: NWEndpoint.Host?
    private var lastControlPort: NWEndpoint.Port?
    private var backoff = ReconnectBackoff(initialMilliseconds: 100, maximumMilliseconds: 5000)
    private var isConnecting = false
    private var retryTask: Task<Void, Never>?

    public init(version: ProtocolVersion, serviceType: String = LumenServices.control) {
        (events, continuation) = AsyncStream.makeStream()
        self.version = version
        self.serviceType = serviceType
    }

    public func start() -> Bool {
        true
    }

    public func activate(identity: LocalIdentity, peer: PairedDevice) {
        trust = (identity, peer)
        startBrowsing(peer: peer)
    }

    public func deactivate() {
        retryTask?.cancel()
        browser?.cancel()
        browser = nil
        closeSession()
        trust = nil
    }

    public func reconnectNow() async {
        guard trust != nil, control == nil, !isConnecting else { return }
        backoff.reset()
        retryTask?.cancel()
        await connectToKnownEndpoint()
    }

    public func send(_ message: PeerMessage) async {
        if case let .dragFrame(sample) = message {
            guard let data = WireCodec.encodeDatagram(sample) else { return }
            realtime?.send(content: data, completion: .idempotent)
        } else if let control, let data = WireCodec.encodeControl(message) {
            try? await control.send(data)
        }
    }

    private func startBrowsing(peer _: PairedDevice) {
        guard let trust, browser == nil else { return }
        let identifier = KeyDerivation.serviceIdentifier(deviceID: trust.peer.deviceID)
        let parameters = NWParameters.tcp
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: serviceType, domain: nil), using: parameters)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let endpoint = results.first { result in
                guard case let .bonjour(record) = result.metadata else { return false }
                return record["id"] == identifier
            }?.endpoint
            Task { await self?.connect(to: endpoint) }
        }
        browser.start(queue: FramedConnection.queue)
        self.browser = browser
    }

    private func connectToKnownEndpoint() async {
        if let lastHost, let lastControlPort {
            await connect(to: .hostPort(host: lastHost, port: lastControlPort))
        } else {
            let endpoint = browser?.browseResults.first?.endpoint
            await connect(to: endpoint)
        }
    }

    private func connect(to endpoint: NWEndpoint?) async {
        guard let endpoint, let trust, control == nil, !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }
        let psk = KeyDerivation.controlPSK(pairingSecret: trust.peer.pairingSecret)
        let channel = FramedConnection(
            connection: NWConnection(to: endpoint, using: SecureParameters.stream(psk: psk))
        ) { [weak self] in
            Task { await self?.controlClosed() }
        }
        control = channel
        do {
            try await channel.start()
            let secrets = try await SessionHandshake.run(
                role: .initiator,
                identity: trust.identity,
                peer: trust.peer,
                version: version,
                channel: channel
            )
            try await openSessionChannels(secrets, channel: channel)
            backoff.reset()
            Task { await readControl(channel) }
        } catch ChannelError.incompatible {
            continuation.yield(.incompatible(supported: version))
            channel.cancel()
        } catch {
            channel.cancel()
            control = nil
            lastHost = nil
            lastControlPort = nil
            scheduleRetry()
        }
    }

    private func openSessionChannels(_ secrets: SessionSecrets, channel: FramedConnection) async throws {
        let message = try await Lumen_ControlMessage(serializedBytes: channel.receive()).message
        guard
            case let .sessionReady(ready) = message,
            case let .hostPort(host, controlPort)? = channel.connection.currentPath?.remoteEndpoint,
            let realtimePort = NWEndpoint.Port(rawValue: UInt16(ready.realtimePort)),
            let filePort = NWEndpoint.Port(rawValue: UInt16(ready.filePort))
        else { throw ChannelError.invalidMessage }
        lastHost = host
        lastControlPort = controlPort
        fileEndpoint = .hostPort(host: host, port: filePort)
        filePSK = secrets.filePSK

        let realtime = NWConnection(
            to: .hostPort(host: host, port: realtimePort),
            using: SecureParameters.datagram(psk: secrets.realtimePSK)
        )
        let hello = try Lumen_Datagram.with {
            $0.message = .hello(.with { $0.protocolVersion = .current })
        }.serializedData()
        let continuation = continuation
        realtime.stateUpdateHandler = { [weak realtime] state in
            if case .ready = state {
                realtime?.send(content: hello, completion: .idempotent)
                continuation.yield(.connected)
            }
        }
        realtime.start(queue: FramedConnection.queue)
        self.realtime = realtime
    }

    private func readControl(_ channel: FramedConnection) async {
        while let data = try? await channel.receive() {
            if let message = WireCodec.decodeControl(data) {
                continuation.yield(.received(message))
            }
        }
        channel.cancel()
    }

    private func controlClosed() {
        guard control != nil, !isConnecting else { return }
        closeSession()
        continuation.yield(.disconnected)
        scheduleRetry()
    }

    private func scheduleRetry() {
        guard trust != nil else { return }
        let delay = backoff.nextDelayMilliseconds()
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            await self?.connectToKnownEndpoint()
        }
    }

    private func closeSession() {
        control?.cancel()
        control = nil
        realtime?.cancel()
        realtime = nil
        fileEndpoint = nil
        filePSK = nil
    }
}
