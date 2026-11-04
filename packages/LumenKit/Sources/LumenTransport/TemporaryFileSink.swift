import CryptoKit
import Foundation
import LumenApplication
import LumenDomain

public actor TemporaryFileSink: FileSinkPort {
    private struct Incoming {
        let offer: TransferOffer
        let directory: URL
        var receivedByResource: [UInt32: UInt64] = [:]
        var verified: Set<UInt32> = []
        var paths: [UInt32: [String]] = [:]
        var lastDigest = ""
    }

    public nonisolated let updates: AsyncStream<TransferUpdate>
    private let continuation: AsyncStream<TransferUpdate>.Continuation
    private let root: URL
    private var incoming: [UInt32: Incoming] = [:]
    private var handles: [String: FileHandle] = [:]

    public init(root: URL) {
        (updates, continuation) = AsyncStream.makeStream()
        self.root = root
        try? FileManager.default.removeItem(at: root)
    }

    public nonisolated func directory(transferID: UInt32) -> URL {
        root.appending(path: String(transferID))
    }

    public func register(_ offer: TransferOffer) {
        guard incoming[offer.transferID] == nil else { return }
        let directory = root.appending(path: String(offer.transferID))
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil
        else { return }
        var transfer = Incoming(offer: offer, directory: directory)
        for resource in offer.resources {
            guard let components = SafeRelativePath.components(of: resource.fileName) else { continue }
            transfer.paths[resource.index] = components
            if resource.isDirectory {
                let folder = components.reduce(directory) { $0.appending(path: $1) }
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                transfer.verified.insert(resource.index)
            }
        }
        incoming[offer.transferID] = transfer
        publishProgress(transfer)
        completeIfReady(offer.transferID)
    }

    public func resumeOffset(transferID: UInt32, resourceIndex: UInt32) -> UInt64? {
        guard let transfer = incoming[transferID], let url = partialURL(transfer, resourceIndex) else { return nil }
        closeHandle(transferID, resourceIndex)
        let manager = FileManager.default
        if !manager.fileExists(atPath: url.path) {
            manager.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url), let size = try? handle.seekToEnd() else { return nil }
        handles[key(transferID, resourceIndex)] = handle
        incoming[transferID]?.receivedByResource[resourceIndex] = size
        return size
    }

    public func append(_ bytes: [UInt8], transferID: UInt32, resourceIndex: UInt32) -> Bool {
        guard let handle = handles[key(transferID, resourceIndex)], incoming[transferID] != nil,
              (try? handle.write(contentsOf: Data(bytes))) != nil else { return false }
        incoming[transferID]?.receivedByResource[resourceIndex, default: 0] += UInt64(bytes.count)
        if let transfer = incoming[transferID] {
            publishProgress(transfer)
        }
        return true
    }

    public func finish(transferID: UInt32, resourceIndex: UInt32, sha256: [UInt8]) -> Bool {
        closeHandle(transferID, resourceIndex)
        guard
            let transfer = incoming[transferID],
            let partial = partialURL(transfer, resourceIndex),
            let components = transfer.paths[resourceIndex],
            let digest = try? FileUploader.sha256(of: partial)
        else { return false }
        guard Array(digest) == sha256 else {
            try? FileManager.default.removeItem(at: partial)
            incoming[transferID]?.receivedByResource[resourceIndex] = 0
            return false
        }
        let final = components.reduce(transfer.directory) { $0.appending(path: $1) }
        let manager = FileManager.default
        try? manager.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? manager.moveItem(at: partial, to: final)) != nil else { return false }
        incoming[transferID]?.verified.insert(resourceIndex)
        incoming[transferID]?.lastDigest = digest.map { String(format: "%02x", $0) }.joined()
        completeIfReady(transferID)
        return true
    }

    public func cancel(transferID: UInt32) {
        guard let transfer = incoming.removeValue(forKey: transferID) else { return }
        for resource in transfer.offer.resources {
            closeHandle(transferID, resource.index)
        }
        try? FileManager.default.removeItem(at: transfer.directory)
        continuation.yield(TransferUpdate(transferID: transferID, stage: .cancelled))
    }

    public func forget(transferID: UInt32) {
        incoming[transferID] = nil
    }

    private func completeIfReady(_ transferID: UInt32) {
        guard
            let transfer = incoming[transferID],
            transfer.verified.count == transfer.offer.resources.count
        else { return }
        let topLevel = Set(transfer.paths.values.compactMap(\.first))
        let delivered = topLevel.count == 1
            ? topLevel.first.map { transfer.directory.appending(path: $0) } ?? transfer.directory
            : transfer.directory
        continuation.yield(TransferUpdate(
            transferID: transferID,
            stage: .completed(path: delivered.path, sha256Hex: transfer.lastDigest)
        ))
    }

    private func publishProgress(_ transfer: Incoming) {
        let received = transfer.receivedByResource.values.reduce(0, +)
        continuation.yield(TransferUpdate(
            transferID: transfer.offer.transferID,
            stage: .receiving(receivedBytes: received, totalBytes: transfer.offer.totalBytes)
        ))
    }

    private func partialURL(_ transfer: Incoming, _ resourceIndex: UInt32) -> URL? {
        guard transfer.paths[resourceIndex] != nil else { return nil }
        return transfer.directory.appending(path: "\(resourceIndex).partial")
    }

    private func key(_ transferID: UInt32, _ resourceIndex: UInt32) -> String {
        "\(transferID)-\(resourceIndex)"
    }

    private func closeHandle(_ transferID: UInt32, _ resourceIndex: UInt32) {
        let handleKey = key(transferID, resourceIndex)
        try? handles[handleKey]?.close()
        handles[handleKey] = nil
    }
}
