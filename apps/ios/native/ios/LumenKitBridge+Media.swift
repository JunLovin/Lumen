import Foundation
import LumenApplication
import LumenDomain

public extension LumenKitBridge {
    private static var dragThumbnailPixels: Double {
        512
    }

    @objc func beginDrag(session frameSession: Int32, assetId: String, phoneHeightMillimeters: Float) {
        let session = session
        let identifier = UInt32(bitPattern: frameSession)
        let transfers = session.transfers
        Task { await transfers.register(transferID: identifier, assetID: assetId) }
        Task {
            await session.send(.dragBegan(DragStart(
                session: identifier,
                thumbnailJPEG: [],
                phoneHeightMillimeters: phoneHeightMillimeters
            )))
        }
        media.loadThumbnail(assetID: assetId, size: Self.dragThumbnailPixels) { uri in
            let bytes = uri.flatMap(URL.init(string:)).flatMap { try? Data(contentsOf: $0) } ?? Data()
            Task {
                await session.send(.dragBegan(DragStart(
                    session: identifier,
                    thumbnailJPEG: Array(bytes),
                    phoneHeightMillimeters: phoneHeightMillimeters
                )))
            }
        }
    }

    @objc func libraryAccess() -> String {
        media.currentAccess()
    }

    @objc func requestLibraryAccess(_ completion: @escaping @Sendable (String) -> Void) {
        let media = media
        Task { await completion(media.requestAccess()) }
    }

    @objc func fetchLibraryAssets(
        offset: Int,
        limit: Int,
        completion: @escaping @Sendable (NSArray) -> Void
    ) {
        completion(media.fetchAssets(offset: offset, limit: limit) as NSArray)
    }

    @objc func loadThumbnail(
        assetId: String,
        size: Double,
        completion: @escaping @Sendable (String?) -> Void
    ) {
        media.loadThumbnail(assetID: assetId, size: size, completion: completion)
    }

    @objc func manageLimitedLibrary() {
        media.presentLimitedPicker()
    }

    @objc func pickFilesToSend() {
        let transfers = session.transfers
        Task { @MainActor in
            let picker = FilePicker { urls in
                Task {
                    let accessible = urls.filter { $0.startAccessingSecurityScopedResource() }
                    await transfers.sendDirect(files: urls)
                    accessible.forEach { $0.stopAccessingSecurityScopedResource() }
                }
            }
            LumenKitBridge.activePicker = picker
            picker.present()
        }
    }

    @objc func listReceivedFiles(_ completion: @escaping @Sendable (NSDictionary) -> Void) {
        let incoming = session.incoming
        Task {
            let snapshot = await incoming.snapshot()
            completion([
                "files": snapshot.files.map { file in
                    [
                        "name": file.name,
                        "uri": file.uri,
                        "isDirectory": file.isDirectory,
                        "byteCount": file.byteCount,
                    ] as [String: Any]
                },
                "receivedBytes": snapshot.receivedBytes,
                "totalBytes": snapshot.totalBytes,
            ])
        }
    }

    @objc func deleteReceivedFile(_ name: String) {
        let incoming = session.incoming
        Task { await incoming.delete(name: name) }
    }
}
