import Foundation
import LumenApplication
import LumenDomain
import LumenTransport

actor TransferSender {
    private let link: PhoneSecureLink
    private let root = FileManager.default.temporaryDirectory.appending(path: "lumen-outgoing")
    private var assets: [UInt32: String] = [:]
    private var tasks: [UInt32: Task<Void, Never>] = [:]

    init(link: PhoneSecureLink) {
        self.link = link
        try? FileManager.default.removeItem(at: root)
    }

    func register(transferID: UInt32, assetID: String) {
        assets[transferID] = assetID
    }

    func start(transferID: UInt32) {
        guard tasks[transferID] == nil, let assetID = assets[transferID] else { return }
        tasks[transferID] = Task { await send(transferID: transferID, assetID: assetID) }
    }

    func cancel(transferID: UInt32) async {
        assets[transferID] = nil
        guard let task = tasks.removeValue(forKey: transferID) else { return }
        task.cancel()
        await task.value
        await link.send(.transferCancel(transferID: transferID))
        removeFiles(transferID)
    }

    private func send(transferID: UInt32, assetID: String) async {
        do {
            let link = link
            let resources = try await AssetExporter.export(
                assetID: assetID,
                to: directory(transferID)
            ) { fraction in
                Task { await link.send(.transferPreparing(transferID: transferID, fraction: fraction)) }
            }
            await link.send(.transferOffer(TransferOffer(
                transferID: transferID,
                resources: resources.map {
                    TransferResource(index: $0.index, fileName: $0.fileName, byteCount: $0.byteCount)
                }
            )))
            for resource in resources {
                try await link.upload(
                    fileAt: resource.url,
                    transferID: transferID,
                    resourceIndex: resource.index
                ) { _ in }
            }
            removeFiles(transferID)
        } catch {
            if !Task.isCancelled {
                await link.send(.transferCancel(transferID: transferID))
                removeFiles(transferID)
            }
        }
    }

    func sendDirect(files urls: [URL]) async {
        let store = FileBatchStore()
        guard let offer = await store.prepareBatch(paths: urls.map(\.path), isDirect: true) else { return }
        await link.send(.transferOffer(offer))
        for resource in offer.resources where !resource.isDirectory {
            guard let file = await store.file(transferID: offer.transferID, resourceIndex: resource.index) else {
                continue
            }
            do {
                try await link.upload(
                    fileAt: file,
                    transferID: offer.transferID,
                    resourceIndex: resource.index
                ) { _ in }
            } catch {
                await link.send(.transferCancel(transferID: offer.transferID))
                return
            }
        }
    }

    private func directory(_ transferID: UInt32) -> URL {
        root.appending(path: String(transferID))
    }

    private func removeFiles(_ transferID: UInt32) {
        try? FileManager.default.removeItem(at: directory(transferID))
    }
}
