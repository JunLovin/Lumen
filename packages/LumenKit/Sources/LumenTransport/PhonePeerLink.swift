import LumenApplication
import LumenDomain
import Network

public actor PhonePeerLink: PeerLinkPort {
    public nonisolated let events: AsyncStream<PeerEvent>
    private let continuation: AsyncStream<PeerEvent>.Continuation
    private let protocolVersion: ProtocolVersion
    private var browser: NWBrowser?
    private var connection: NWConnection?

    private let serviceType: String

    public init(protocolVersion: ProtocolVersion, serviceType: String = DatagramService.bonjourType) {
        (events, continuation) = AsyncStream.makeStream()
        self.serviceType = serviceType
        self.protocolVersion = protocolVersion
    }

    public func start() -> Bool {
        guard browser == nil else { return true }
        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .udp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let endpoint = results.first?.endpoint
            Task { await self?.connect(to: endpoint) }
        }
        browser.start(queue: DatagramService.queue)
        self.browser = browser
        return true
    }

    public func send(_ message: PeerMessage) {
        connection?.send(message: message)
    }

    private func connect(to endpoint: NWEndpoint?) {
        guard let endpoint, connection == nil else { return }
        let newConnection = NWConnection(to: endpoint, using: .udp)
        connection = newConnection
        newConnection.stateUpdateHandler = { [weak self] state in
            Task { await self?.handle(state) }
        }
        let continuation = continuation
        newConnection.start(queue: DatagramService.queue)
        newConnection.receiveMessages { continuation.yield(.received($0)) }
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connection?.send(message: .hello(protocolVersion))
            continuation.yield(.connected)
        case .failed, .cancelled:
            connection = nil
            continuation.yield(.disconnected)
            connect(to: browser?.browseResults.first?.endpoint)
        default:
            break
        }
    }
}
