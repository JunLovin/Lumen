import Foundation
import LumenApplication
import LumenDomain

public actor FileBatchStore: FileSourcePort {
    private static let ignoredNames: Set<String> = [".DS_Store"]
    private var batches: [UInt32: [UInt32: URL]] = [:]

    public init() {}

    public func prepareBatch(paths: [String], isDirect: Bool) -> TransferOffer? {
        var resources: [TransferResource] = []
        var files: [UInt32: URL] = [:]
        for path in paths {
            collect(URL(filePath: path), named: URL(filePath: path).lastPathComponent, into: &resources, files: &files)
        }
        guard !resources.isEmpty else { return nil }
        let transferID = UInt32.random(in: 1 ... .max)
        batches[transferID] = files
        return TransferOffer(transferID: transferID, resources: resources, isDirect: isDirect)
    }

    public func discard(transferID: UInt32) {
        batches[transferID] = nil
    }

    public func file(transferID: UInt32, resourceIndex: UInt32) -> URL? {
        batches[transferID]?[resourceIndex]
    }

    private func collect(
        _ url: URL,
        named name: String,
        into resources: inout [TransferResource],
        files: inout [UInt32: URL]
    ) {
        guard !Self.ignoredNames.contains(url.lastPathComponent) else { return }
        let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .fileSizeKey])
        guard let values, values.isSymbolicLink != true else { return }
        let index = UInt32(resources.count)
        guard values.isDirectory == true else {
            resources.append(TransferResource(index: index, fileName: name, byteCount: UInt64(values.fileSize ?? 0)))
            files[index] = url
            return
        }
        resources.append(TransferResource(index: index, fileName: name, byteCount: 0, isDirectory: true))
        let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        for child in children {
            collect(child, named: "\(name)/\(child.lastPathComponent)", into: &resources, files: &files)
        }
    }
}
