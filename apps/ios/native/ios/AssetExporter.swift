import Foundation
import Photos
import Synchronization

struct ExportedResource {
    let index: UInt32
    let fileName: String
    let url: URL
    let byteCount: UInt64
}

private struct ChosenResource {
    let source: PHAssetResource
    let name: String
}

enum AssetExporter {
    private static let originalTypes: Set<PHAssetResourceType> = [.photo, .alternatePhoto, .video, .pairedVideo]
    private static let editedVersions: [PHAssetResourceType: PHAssetResourceType] = [
        .photo: .fullSizePhoto,
        .video: .fullSizeVideo,
        .pairedVideo: .fullSizePairedVideo,
    ]

    static func export(
        assetID: String,
        to directory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [ExportedResource] {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let resources = chosenResources(of: asset)
        let resourceCount = Double(max(resources.count, 1))
        var exported: [ExportedResource] = []
        var usedNames: Set<String> = []
        for (index, resource) in resources.enumerated() {
            try Task.checkCancellation()
            let name = usedNames.contains(resource.name)
                ? "\(index)-\(resource.name)"
                : resource.name
            usedNames.insert(name)
            let url = directory.appending(path: "\(index).export")
            let share = { @Sendable (fraction: Double) in
                progress((Double(index) + fraction) / resourceCount)
            }
            try await write(resource.source, to: url, progress: share)
            let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
            exported.append(ExportedResource(index: UInt32(index), fileName: name, url: url, byteCount: size))
        }
        return exported
    }

    /// Prefers the edited version, because that is what the gallery shows, under the original's name.
    private static func chosenResources(of asset: PHAsset) -> [ChosenResource] {
        let all = PHAssetResource.assetResources(for: asset)
        return all.filter { originalTypes.contains($0.type) }.map { original in
            let edited = editedVersions[original.type].flatMap { type in all.first { $0.type == type } }
            guard let edited else {
                return ChosenResource(source: original, name: original.originalFilename)
            }
            let stem = (original.originalFilename as NSString).deletingPathExtension
            let suffix = (edited.originalFilename as NSString).pathExtension
            return ChosenResource(source: edited, name: "\(stem).\(suffix)")
        }
    }

    private static func write(
        _ resource: PHAssetResource,
        to url: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress($0) }
        let manager = PHAssetResourceManager.default()
        let request = Mutex<PHAssetResourceDataRequestID?>(nil)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let identifier = manager.requestData(for: resource, options: options) { data in
                    try? handle.write(contentsOf: data)
                } completionHandler: { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
                request.withLock { $0 = identifier }
            }
        } onCancel: {
            if let identifier = request.withLock({ $0 }) {
                PHAssetResourceManager.default().cancelDataRequest(identifier)
            }
        }
    }
}
