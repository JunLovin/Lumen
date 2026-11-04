import CryptoKit
import Foundation
import LumenApplication
import LumenProtocol

enum FileReceiver {
    static func serve(on channel: FramedConnection, sink: any FileSinkPort, source: FileBatchStore) async {
        defer { channel.cancel() }
        guard
            await (try? channel.start()) != nil,
            let first = try? await receive(channel)
        else { return }
        switch first {
        case let .probe(payload):
            try? await channel.send(Data(SHA256.hash(data: payload)))
        case let .header(header) where header.download:
            try? await sendFile(header, on: channel, source: source)
        case let .header(header):
            try? await receiveFile(header, on: channel, sink: sink)
        default:
            break
        }
    }

    private static func sendFile(
        _ header: Lumen_FileHeader,
        on channel: FramedConnection,
        source: FileBatchStore
    ) async throws {
        guard let url = await source.file(transferID: header.transferID, resourceIndex: header.resourceIndex) else {
            return
        }
        try await FileUploader.streamBlocks(of: url, from: header.offset, on: channel)
        _ = try await receive(channel)
    }

    private static func receiveFile(
        _ header: Lumen_FileHeader,
        on channel: FramedConnection,
        sink: any FileSinkPort
    ) async throws {
        let transferID = header.transferID
        let index = header.resourceIndex
        guard let offset = await sink.resumeOffset(transferID: transferID, resourceIndex: index) else { return }
        try await channel.send(frame(.resume(.with { $0.offset = offset })))
        while true {
            switch try await receive(channel) {
            case let .block(data):
                guard await sink.append(Array(data), transferID: transferID, resourceIndex: index) else { return }
            case let .end(end):
                let verified = await sink.finish(
                    transferID: transferID,
                    resourceIndex: index,
                    sha256: Array(end.sha256)
                )
                try await channel.send(frame(.ack(.with { $0.verified = verified })))
                return
            default:
                throw ChannelError.invalidMessage
            }
        }
    }
}

enum FileUploader {
    private static let blockBytes = 1024 * 1024

    static func upload(
        fileAt url: URL,
        transferID: UInt32,
        resourceIndex: UInt32,
        channel: FramedConnection,
        progress: @Sendable (UInt64) -> Void
    ) async throws -> Bool {
        defer { channel.cancel() }
        do {
            try await channel.start()
            try await channel.send(frame(.header(.with {
                $0.transferID = transferID
                $0.resourceIndex = resourceIndex
            })))
            guard case let .resume(resume) = try await receive(channel) else { return false }
            try await streamBlocks(of: url, from: resume.offset, on: channel, progress: progress)
            guard case let .ack(ack) = try await receive(channel) else { return false }
            return ack.verified
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return false
        }
    }

    static func streamBlocks(
        of url: URL,
        from offset: UInt64,
        on channel: FramedConnection,
        progress: @Sendable (UInt64) -> Void = { _ in }
    ) async throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)
        var sent = offset
        while let block = try handle.read(upToCount: blockBytes), !block.isEmpty {
            try Task.checkCancellation()
            try await channel.send(frame(.block(block)))
            sent += UInt64(block.count)
            progress(sent)
        }
        let digest = try sha256(of: url)
        try await channel.send(frame(.end(.with { $0.sha256 = digest })))
    }

    static func download(
        transferID: UInt32,
        resourceIndex: UInt32,
        channel: FramedConnection,
        sink: any FileSinkPort
    ) async throws -> Bool {
        defer { channel.cancel() }
        do {
            try await channel.start()
            guard let offset = await sink.resumeOffset(transferID: transferID, resourceIndex: resourceIndex) else {
                return true
            }
            try await channel.send(frame(.header(.with {
                $0.transferID = transferID
                $0.resourceIndex = resourceIndex
                $0.download = true
                $0.offset = offset
            })))
            while true {
                try Task.checkCancellation()
                switch try await receive(channel) {
                case let .block(data):
                    guard await sink.append(Array(data), transferID: transferID, resourceIndex: resourceIndex) else {
                        return false
                    }
                case let .end(end):
                    let verified = await sink.finish(
                        transferID: transferID,
                        resourceIndex: resourceIndex,
                        sha256: Array(end.sha256)
                    )
                    try await channel.send(frame(.ack(.with { $0.verified = verified })))
                    return verified
                default:
                    return false
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return false
        }
    }

    static func sha256(of url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let block = try handle.read(upToCount: blockBytes), !block.isEmpty {
            hasher.update(data: block)
        }
        return Data(hasher.finalize())
    }
}

private func receive(_ channel: FramedConnection) async throws -> Lumen_FileMessage.OneOf_Message {
    guard let message = try await Lumen_FileMessage(serializedBytes: channel.receive()).message else {
        throw ChannelError.invalidMessage
    }
    return message
}

private func frame(_ message: Lumen_FileMessage.OneOf_Message) throws -> Data {
    var wrapped = Lumen_FileMessage()
    wrapped.message = message
    return try wrapped.serializedData()
}
