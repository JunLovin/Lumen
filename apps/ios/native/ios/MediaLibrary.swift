import CryptoKit
import Foundation
import Photos
import PhotosUI
import UIKit

final class MediaLibrary: Sendable {
    private static let jpegQuality = 0.8

    func currentAccess() -> String {
        Self.name(of: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> String {
        await Self.name(of: PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    private static func name(of status: PHAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            "authorized"
        case .limited:
            "limited"
        case .denied, .restricted:
            "denied"
        default:
            "undetermined"
        }
    }

    func fetchAssets(offset: Int, limit: Int) -> [[String: Any]] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        let end = min(offset + limit, result.count)
        guard offset < end else { return [] }
        return result.objects(at: IndexSet(offset ..< end)).map { asset in
            [
                "id": asset.localIdentifier,
                "width": asset.pixelWidth,
                "height": asset.pixelHeight,
                "mediaType": asset.mediaType == .video ? "video" : "photo",
            ]
        }
    }

    func loadThumbnail(assetID: String, size: Double, completion: @escaping @Sendable (String?) -> Void) {
        let file = Self.cacheFile(assetID: assetID, size: size)
        guard !FileManager.default.fileExists(atPath: file.path) else {
            completion(file.absoluteString)
            return
        }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
            completion(nil)
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: size, height: size),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            guard let data = image?.jpegData(compressionQuality: Self.jpegQuality), (try? data.write(to: file)) != nil
            else {
                completion(nil)
                return
            }
            completion(file.absoluteString)
        }
    }

    func presentLimitedPicker() {
        Task { @MainActor in
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            guard let root = scene?.keyWindow?.rootViewController else { return }
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
        }
    }

    private static func cacheFile(assetID: String, size: Double) -> URL {
        let digest = SHA256.hash(data: Data("\(assetID)-\(Int(size))".utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return FileManager.default.temporaryDirectory.appending(path: "lumen-thumb-\(name).jpg")
    }
}
