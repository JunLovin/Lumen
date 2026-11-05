import Foundation

public extension LumenKitBridge {
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
