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
}
