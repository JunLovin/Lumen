import CryptoKit
import Foundation
import LumenDomain
import LumenTransport
import Testing

private func makeRoot() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "lumen-sink-\(UUID().uuidString)")
}

private func digest(_ bytes: [UInt8]) -> [UInt8] {
    Array(SHA256.hash(data: Data(bytes)))
}

private func offer(id: UInt32 = 1, names: [String], size: UInt64 = 4) -> TransferOffer {
    TransferOffer(transferID: id, resources: names.enumerated().map {
        TransferResource(index: UInt32($0.offset), fileName: $0.element, byteCount: size)
    })
}

private func completedPath(in sink: TemporaryFileSink) async -> String? {
    for await update in sink.updates {
        if case let .completed(path, _) = update.stage {
            return path
        }
    }
    return nil
}

@Test func storesAVerifiedFileUnderItsOriginalName() async throws {
    let sink = TemporaryFileSink(root: makeRoot())
    await sink.register(offer(names: ["IMG_1.HEIC"]))
    #expect(await sink.resumeOffset(transferID: 1, resourceIndex: 0) == 0)
    #expect(await sink.append([1, 2, 3, 4], transferID: 1, resourceIndex: 0))
    #expect(await sink.finish(transferID: 1, resourceIndex: 0, sha256: digest([1, 2, 3, 4])))
    let path = try #require(await completedPath(in: sink))
    #expect(path.hasSuffix("IMG_1.HEIC"))
    #expect(try Data(contentsOf: URL(filePath: path)) == Data([1, 2, 3, 4]))
}

@Test func resumesFromWhatItAlreadyHas() async {
    let sink = TemporaryFileSink(root: makeRoot())
    await sink.register(offer(names: ["a.mov"]))
    _ = await sink.resumeOffset(transferID: 1, resourceIndex: 0)
    _ = await sink.append([1, 2], transferID: 1, resourceIndex: 0)
    #expect(await sink.resumeOffset(transferID: 1, resourceIndex: 0) == 2)
    _ = await sink.append([3, 4], transferID: 1, resourceIndex: 0)
    #expect(await sink.finish(transferID: 1, resourceIndex: 0, sha256: digest([1, 2, 3, 4])))
}

@Test func aWrongHashDiscardsTheFileSoItCanRestart() async {
    let sink = TemporaryFileSink(root: makeRoot())
    await sink.register(offer(names: ["a.mov"]))
    _ = await sink.resumeOffset(transferID: 1, resourceIndex: 0)
    _ = await sink.append([1, 2], transferID: 1, resourceIndex: 0)
    #expect(await !sink.finish(transferID: 1, resourceIndex: 0, sha256: digest([9])))
    #expect(await sink.resumeOffset(transferID: 1, resourceIndex: 0) == 0)
}

@Test func aLivePhotoCompletesAsAFolderOnlyAfterBothParts() async throws {
    let sink = TemporaryFileSink(root: makeRoot())
    await sink.register(offer(names: ["a.heic", "a.mov"]))
    for index in [UInt32(0), 1] {
        _ = await sink.resumeOffset(transferID: 1, resourceIndex: index)
        _ = await sink.append([UInt8(index)], transferID: 1, resourceIndex: index)
        #expect(await sink.finish(transferID: 1, resourceIndex: index, sha256: digest([UInt8(index)])))
    }
    let path = try #require(await completedPath(in: sink))
    let contents = try FileManager.default.contentsOfDirectory(atPath: path).sorted()
    #expect(contents == ["a.heic", "a.mov"])
}

@Test func cancellingLeavesNoResidue() async throws {
    let root = makeRoot()
    let sink = TemporaryFileSink(root: root)
    await sink.register(offer(names: ["a.mov"]))
    _ = await sink.resumeOffset(transferID: 1, resourceIndex: 0)
    _ = await sink.append([1, 2], transferID: 1, resourceIndex: 0)
    await sink.cancel(transferID: 1)
    let contents = try FileManager.default.contentsOfDirectory(atPath: root.path)
    #expect(contents.isEmpty)
    #expect(await sink.resumeOffset(transferID: 1, resourceIndex: 0) == nil)
}

@Test func aPathTraversalNameStaysInsideTheTransferFolder() async throws {
    let root = makeRoot()
    let sink = TemporaryFileSink(root: root)
    await sink.register(offer(names: ["../../../evil.txt"]))
    _ = await sink.resumeOffset(transferID: 1, resourceIndex: 0)
    _ = await sink.append([1], transferID: 1, resourceIndex: 0)
    _ = await sink.finish(transferID: 1, resourceIndex: 0, sha256: digest([1]))
    let path = try #require(await completedPath(in: sink))
    #expect(URL(filePath: path).standardized.path.hasPrefix(root.standardized.path))
    #expect(path.hasSuffix("evil.txt"))
}

@Test func anUnsafeNameIsRejected() async {
    let sink = TemporaryFileSink(root: makeRoot())
    await sink.register(offer(names: [".."]))
    #expect(await sink.resumeOffset(transferID: 1, resourceIndex: 0) == nil)
}

@Test func aRepeatedOfferDoesNotDisturbATransferInProgress() async {
    let sink = TemporaryFileSink(root: makeRoot())
    await sink.register(offer(names: ["a.mov"]))
    _ = await sink.resumeOffset(transferID: 1, resourceIndex: 0)
    _ = await sink.append([1, 2], transferID: 1, resourceIndex: 0)
    await sink.register(offer(names: ["a.mov"]))
    #expect(await sink.resumeOffset(transferID: 1, resourceIndex: 0) == 2)
}
