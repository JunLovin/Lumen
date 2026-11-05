import CryptoKit
import Foundation
import LumenProtocol

public enum FileProbe {
    /// A capture of the file channel must never contain this text.
    public static let plaintextCanary = "LUMEN-PLAINTEXT-CANARY"
    private static let blockBytes = 1024 * 1024

    static func block() -> Data {
        let canary = Data(plaintextCanary.utf8)
        return Data((0 ..< blockBytes / canary.count).flatMap { _ in canary })
    }

    static func run(on channel: FramedConnection) async -> Bool {
        defer { channel.cancel() }
        let payload = block()
        var message = Lumen_FileMessage()
        message.message = .probe(payload)
        guard
            await (try? channel.start()) != nil,
            let frame = try? message.serializedData(),
            await (try? channel.send(frame)) != nil,
            let digest = try? await channel.receive()
        else { return false }
        return digest == Data(SHA256.hash(data: payload))
    }
}
