import LumenApplication
import Network

public actor MacPeerLink: PeerLinkPort {
    public nonisolated let events: AsyncStream<PeerEvent>
    private let continuation: AsyncStream<PeerEvent>.Continuation
    private var listener: NWListener?
    private var connection: NWConnection?

    public init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    public func start() -> Bool {
        guard let listener = try? NWListener(using: .udp) else { return false }
        listener.service = NWListener.Service(type: DatagramService.bonjourType)
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.adopt(connection) }
        }
        listener.start(queue: DatagramService.queue)
        self.listener = listener
        return true
    }

    public func send(_ message: PeerMessage) {
        connection?.send(message: message)
    }

    private func adopt(_ newConnection: NWConnection) {
        connection?.cancel()
        connection = newConnection
        let continuation = continuation
        newConnection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                continuation.yield(.connected)
            case .failed, .cancelled:
                continuation.yield(.disconnected)
            default:
                break
            }
        }
        newConnection.start(queue: DatagramService.queue)
        newConnection.receiveMessages { continuation.yield(.received($0)) }
    }
}
