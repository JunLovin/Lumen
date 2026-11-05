import Foundation
import LumenApplication
import LumenDomain
import Network

public enum LumenServices {
    public static let control = "_lumen._tcp"
    public static let pairing = "_lumen-pair._tcp"
}

public actor PairingResponder: PairingPort {
    private let serviceType: String
    private var listener: NWListener?
    private var channel: FramedConnection?
    private var pending: PairingExchange?
    private var continuation: AsyncStream<PairingStage>.Continuation?

    public init(serviceType: String = LumenServices.pairing) {
        self.serviceType = serviceType
    }

    public func begin(identity: LocalIdentity) -> AsyncStream<PairingStage> {
        let (stream, continuation) = AsyncStream.makeStream(of: PairingStage.self)
        self.continuation = continuation
        guard let listener = try? NWListener(using: SecureParameters.plainStream()) else {
            continuation.yield(.failed(.connectionLost))
            continuation.finish()
            return stream
        }
        listener.service = NWListener.Service(type: serviceType)
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection, identity: identity) }
        }
        listener.start(queue: FramedConnection.queue)
        self.listener = listener
        continuation.yield(.exchanging)
        return stream
    }

    public func confirm() async {
        guard let pending, let channel else { return }
        do {
            try await channel.send(PairingExchange.confirmedMessage(pending.confirmation))
            continuation?.yield(.paired(pending.pairedDevice()))
        } catch {
            continuation?.yield(.failed(.connectionLost))
        }
        finish()
    }

    public func cancel() {
        channel?.cancel()
        finish()
    }

    private func accept(_ connection: NWConnection, identity: LocalIdentity) async {
        guard channel == nil else {
            connection.cancel()
            return
        }
        let channel = FramedConnection(connection: connection)
        self.channel = channel
        do {
            try await channel.start()
            let exchange = try await PairingExchange.run(role: .responder, identity: identity, channel: channel)
            pending = exchange
            continuation?.yield(.awaitingConfirmation(exchange.verificationPattern))
        } catch {
            continuation?.yield(.failed(.verificationFailed))
            finish()
        }
    }

    private func finish() {
        listener?.cancel()
        listener = nil
        channel = nil
        pending = nil
        continuation?.finish()
        continuation = nil
    }
}

public actor PairingInitiator: PairingPort {
    private static let connectRetryDelay = Duration.milliseconds(500)

    private let serviceType: String
    private var browser: NWBrowser?
    private var channel: FramedConnection?
    private var continuation: AsyncStream<PairingStage>.Continuation?

    public init(serviceType: String = LumenServices.pairing) {
        self.serviceType = serviceType
    }

    public func begin(identity: LocalIdentity) -> AsyncStream<PairingStage> {
        let (stream, continuation) = AsyncStream.makeStream(of: PairingStage.self)
        self.continuation = continuation
        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: SecureParameters.plainStream())
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let endpoint = results.first?.endpoint else { return }
            Task { await self?.connect(to: endpoint, identity: identity) }
        }
        browser.start(queue: FramedConnection.queue)
        self.browser = browser
        continuation.yield(.searching)
        return stream
    }

    public func confirm() {}

    public func cancel() {
        channel?.cancel()
        finish()
    }

    private func connect(to endpoint: NWEndpoint, identity: LocalIdentity) async {
        guard channel == nil else { return }
        let channel = FramedConnection(connection: NWConnection(to: endpoint, using: SecureParameters.plainStream()))
        self.channel = channel
        guard await (try? channel.start()) != nil else {
            await retryConnecting(to: endpoint, identity: identity)
            return
        }
        do {
            continuation?.yield(.exchanging)
            let exchange = try await PairingExchange.run(role: .initiator, identity: identity, channel: channel)
            continuation?.yield(.awaitingConfirmation(exchange.verificationPattern))
            let confirmed = try await channel.receive()
            guard PairingExchange.isConfirmed(confirmed, expected: exchange.confirmation) else {
                throw ChannelError.handshakeFailed
            }
            continuation?.yield(.paired(exchange.pairedDevice()))
        } catch {
            continuation?.yield(.failed(.rejected))
        }
        channel.cancel()
        finish()
    }

    private func retryConnecting(to endpoint: NWEndpoint, identity: LocalIdentity) async {
        channel = nil
        try? await Task.sleep(for: Self.connectRetryDelay)
        guard browser != nil else { return }
        await connect(to: browser?.browseResults.first?.endpoint ?? endpoint, identity: identity)
    }

    private func finish() {
        browser?.cancel()
        browser = nil
        channel = nil
        continuation?.finish()
        continuation = nil
    }
}
