import CryptoKit
import Foundation
import LumenApplication
import LumenDomain
import LumenProtocol
import Network

public actor MacSecureLink: SecureLinkPort {
    public nonisolated let events: AsyncStream<PeerEvent>
    private let continuation: AsyncStream<PeerEvent>.Continuation
    private let serviceType: String
    private let version: ProtocolVersion
    private let sink: any FileSinkPort
    private var trust: (identity: LocalIdentity, peer: PairedDevice)?
    private var controlListener: NWListener?
    private var control: FramedConnection?
    private var realtimeListener: NWListener?
    private var fileListener: NWListener?

    public init(version: ProtocolVersion, sink: any FileSinkPort, serviceType: String = LumenServices.control) {
        (events, continuation) = AsyncStream.makeStream()
        self.sink = sink
        self.version = version
        self.serviceType = serviceType
    }

    public func start() -> Bool {
        true
    }

    public func activate(identity: LocalIdentity, peer: PairedDevice) {
        trust = (identity, peer)
        let psk = KeyDerivation.controlPSK(pairingSecret: peer.pairingSecret)
        guard let listener = try? NWListener(using: SecureParameters.stream(psk: psk)) else { return }
        var record = NWTXTRecord()
        record["v"] = String(version.rawValue)
        record["id"] = KeyDerivation.serviceIdentifier(deviceID: identity.deviceID)
        listener.service = NWListener.Service(type: serviceType, txtRecord: record)
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection) }
        }
        listener.start(queue: FramedConnection.queue)
        controlListener = listener
    }

    public func deactivate() {
        closeSession()
        controlListener?.cancel()
        controlListener = nil
        trust = nil
    }

    public func dropSessionForTesting() {
        closeSession()
    }

    public func send(_ message: PeerMessage) async {
        guard let control, let data = WireCodec.encodeControl(message) else { return }
        try? await control.send(data)
    }

    private func accept(_ connection: NWConnection) async {
        guard let trust else {
            connection.cancel()
            return
        }
        closeSession()
        let continuation = continuation
        let channel = FramedConnection(connection: connection) { continuation.yield(.disconnected) }
        control = channel
        do {
            try await channel.start()
            let secrets = try await SessionHandshake.run(
                role: .responder,
                identity: trust.identity,
                peer: trust.peer,
                version: version,
                channel: channel
            )
            try await openSessionChannels(secrets, channel: channel)
            Task { await readControl(channel) }
        } catch {
            channel.cancel()
        }
    }

    private func openSessionChannels(_ secrets: SessionSecrets, channel: FramedConnection) async throws {
        let realtime = try NWListener(using: SecureParameters.datagram(psk: secrets.realtimePSK))
        let file = try NWListener(using: SecureParameters.stream(psk: secrets.filePSK))
        let continuation = continuation
        let sink = sink
        realtime.newConnectionHandler = { connection in
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    continuation.yield(.connected)
                }
            }
            connection.start(queue: FramedConnection.queue)
            connection.receiveDatagrams { data in
                if let message = WireCodec.decodeDatagram(data) {
                    continuation.yield(.received(message))
                }
            }
        }
        file.newConnectionHandler = { connection in
            Task { await FileReceiver.serve(on: FramedConnection(connection: connection), sink: sink) }
        }
        let realtimePort = try await ready(realtime)
        let filePort = try await ready(file)
        realtimeListener = realtime
        fileListener = file
        var message = Lumen_ControlMessage()
        message.message = .sessionReady(.with {
            $0.realtimePort = UInt32(realtimePort)
            $0.filePort = UInt32(filePort)
        })
        try await channel.send(message.serializedData())
    }

    private func ready(_ listener: NWListener) async throws -> UInt16 {
        for await port in Self.ports(of: listener) {
            return port
        }
        throw ChannelError.closed
    }

    private static func ports(of listener: NWListener) -> AsyncStream<UInt16> {
        AsyncStream { stream in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    stream.yield(listener.port?.rawValue ?? 0)
                    stream.finish()
                case .failed, .cancelled:
                    stream.finish()
                default:
                    break
                }
            }
            listener.start(queue: FramedConnection.queue)
        }
    }

    private func readControl(_ channel: FramedConnection) async {
        while let data = try? await channel.receive() {
            if let message = WireCodec.decodeControl(data) {
                continuation.yield(.received(message))
            }
        }
        channel.cancel()
    }

    private func closeSession() {
        control?.cancel()
        control = nil
        realtimeListener?.cancel()
        realtimeListener = nil
        fileListener?.cancel()
        fileListener = nil
    }
}
