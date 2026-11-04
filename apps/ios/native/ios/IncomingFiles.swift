import Foundation
import LumenApplication
import LumenDomain
import LumenTransport

struct InboxFile {
    let name: String
    let uri: String
    let isDirectory: Bool
    let byteCount: Int
}

struct InboxSnapshot {
    let files: [InboxFile]
    let receivedBytes: UInt64
    let totalBytes: UInt64
}

actor IncomingFiles {
    private let link: PhoneSecureLink
    private let sink = TemporaryFileSink(
        root: FileManager.default.temporaryDirectory.appending(path: "lumen-incoming")
    )
    private var tasks: [UInt32: Task<Void, Never>] = [:]
    private var progress: [UInt32: (received: UInt64, total: UInt64)] = [:]
    private var isConsuming = false

    private static var inbox: URL {
        URL.documentsDirectory.appending(path: "Recibidos")
    }

    init(link: PhoneSecureLink) {
        self.link = link
    }

    func accept(_ offer: TransferOffer) async {
        startConsuming()
        await sink.register(offer)
        let transferID = offer.transferID
        let files = offer.resources.filter { !$0.isDirectory }
        let link = link
        let sink = sink
        tasks[transferID] = Task {
            do {
                for file in files {
                    try await link.download(transferID: transferID, resourceIndex: file.index, into: sink)
                }
            } catch {
                await sink.cancel(transferID: transferID)
                await link.send(.transferCancel(transferID: transferID))
            }
        }
    }

    func cancel(transferID: UInt32) async {
        tasks.removeValue(forKey: transferID)?.cancel()
        await sink.cancel(transferID: transferID)
    }

    func snapshot() -> InboxSnapshot {
        InboxSnapshot(
            files: Self.listInbox(),
            receivedBytes: progress.values.reduce(0) { $0 + $1.received },
            totalBytes: progress.values.reduce(0) { $0 + $1.total }
        )
    }

    func delete(name: String) {
        guard SafeRelativePath.components(of: name)?.count == 1 else { return }
        try? FileManager.default.removeItem(at: Self.inbox.appending(path: name))
    }

    private func startConsuming() {
        guard !isConsuming else { return }
        isConsuming = true
        let updates = sink.updates
        Task {
            for await update in updates {
                await handle(update)
            }
        }
    }

    private func handle(_ update: TransferUpdate) async {
        switch update.stage {
        case let .receiving(received, total):
            progress[update.transferID] = (received, total)
        case let .completed(path, _):
            progress[update.transferID] = nil
            deliver(URL(filePath: path))
            try? FileManager.default.removeItem(at: sink.directory(transferID: update.transferID))
            await sink.forget(transferID: update.transferID)
        case .failed, .cancelled:
            progress[update.transferID] = nil
        case .preparing:
            break
        }
    }

    private func deliver(_ source: URL) {
        let manager = FileManager.default
        try? manager.createDirectory(at: Self.inbox, withIntermediateDirectories: true)
        let stem = source.deletingPathExtension().lastPathComponent
        let suffix = source.pathExtension
        var target = Self.inbox.appending(path: source.lastPathComponent)
        var attempt = 2
        while manager.fileExists(atPath: target.path) {
            let name = "\(stem) \(attempt)" + (suffix.isEmpty ? "" : ".\(suffix)")
            target = Self.inbox.appending(path: name)
            attempt += 1
        }
        try? manager.moveItem(at: source, to: target)
    }

    private static func listInbox() -> [InboxFile] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let entries = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: keys)) ?? []
        return entries
            .map { (url: $0, values: try? $0.resourceValues(forKeys: Set(keys))) }
            .sorted {
                ($0.values?.contentModificationDate ?? .distantPast) >
                    ($1.values?.contentModificationDate ?? .distantPast)
            }
            .map { entry in
                InboxFile(
                    name: entry.url.lastPathComponent,
                    uri: entry.url.absoluteString,
                    isDirectory: entry.values?.isDirectory ?? false,
                    byteCount: entry.values?.fileSize ?? 0
                )
            }
    }
}
