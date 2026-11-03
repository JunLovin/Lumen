import Foundation
import LumenApplication
import Network

enum DatagramService {
    static let bonjourType = "_lumen._udp"
    static let queue = DispatchQueue(label: "lumen.transport", qos: .userInteractive)
}

extension NWConnection {
    func receiveMessages(_ handler: @escaping @Sendable (PeerMessage) -> Void) {
        receiveMessage { [weak self] content, _, _, error in
            if let content, let message = DatagramCodec.decode(content) {
                handler(message)
            }
            if error == nil {
                self?.receiveMessages(handler)
            }
        }
    }

    func send(message: PeerMessage) {
        guard let data = DatagramCodec.encode(message) else { return }
        send(content: data, completion: .idempotent)
    }
}
