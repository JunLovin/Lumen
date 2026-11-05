import Foundation
import Network
import Synchronization

public enum ChannelError: Error, Equatable {
    case closed
    case frameTooLarge
    case handshakeFailed
    case incompatible
    case invalidMessage
}

final class FramedConnection: Sendable {
    static let queue = DispatchQueue(label: "lumen.transport", qos: .userInteractive)
    static let maximumFrameBytes = 2 * 1024 * 1024
    private static let headerBytes = 4

    let connection: NWConnection
    private let readiness = Mutex<CheckedContinuation<Void, any Error>?>(nil)
    private let onClose: @Sendable () -> Void

    init(connection: NWConnection, onClose: @escaping @Sendable () -> Void = {}) {
        self.connection = connection
        self.onClose = onClose
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            readiness.withLock { $0 = continuation }
            connection.stateUpdateHandler = { [weak self] state in self?.handle(state) }
            connection.start(queue: Self.queue)
        }
    }

    func send(_ payload: Data) async throws {
        guard payload.count <= Self.maximumFrameBytes else { throw ChannelError.frameTooLarge }
        var length = UInt32(payload.count).bigEndian
        let frame = Data(bytes: &length, count: Self.headerBytes) + payload
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: frame, completion: .contentProcessed { error in
                if error == nil {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ChannelError.closed)
                }
            })
        }
    }

    func receive() async throws -> Data {
        let header = try await receive(exactly: Self.headerBytes)
        let length = header.reduce(0) { $0 << 8 | Int($1) }
        guard length <= Self.maximumFrameBytes else { throw ChannelError.frameTooLarge }
        return length == 0 ? Data() : try await receive(exactly: length)
    }

    func cancel() {
        connection.cancel()
    }

    private func receive(exactly count: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
                if let data, data.count == count, error == nil {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: ChannelError.closed)
                }
            }
        }
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            resumeReadiness(with: nil)
        case .waiting:
            resumeReadiness(with: ChannelError.handshakeFailed)
            connection.cancel()
        case .failed, .cancelled:
            resumeReadiness(with: ChannelError.closed)
            onClose()
        default:
            break
        }
    }

    private func resumeReadiness(with error: (any Error)?) {
        let continuation = readiness.withLock { current in
            defer { current = nil }
            return current
        }
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }
}

extension NWConnection {
    func receiveDatagrams(_ handler: @escaping @Sendable (Data) -> Void) {
        receiveMessage { [weak self] content, _, _, error in
            if let content {
                handler(content)
            }
            if error == nil {
                self?.receiveDatagrams(handler)
            }
        }
    }
}
