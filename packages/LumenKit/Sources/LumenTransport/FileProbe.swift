import CryptoKit
import Foundation

public enum FileProbe {
    /// A capture of the file channel must never contain this text.
    public static let plaintextCanary = "LUMEN-PLAINTEXT-CANARY"
    private static let blockBytes = 1024 * 1024

    static func block() -> Data {
        let canary = Data(plaintextCanary.utf8)
        return Data((0 ..< blockBytes / canary.count).flatMap { _ in canary })
    }

    static func answer(on channel: FramedConnection) async {
        defer { channel.cancel() }
        guard
            await (try? channel.start()) != nil,
            let received = try? await channel.receive()
        else { return }
        try? await channel.send(Data(SHA256.hash(data: received)))
    }

    static func run(on channel: FramedConnection) async -> Bool {
        defer { channel.cancel() }
        let payload = block()
        guard
            await (try? channel.start()) != nil,
            await (try? channel.send(payload)) != nil,
            let digest = try? await channel.receive()
        else { return false }
        return digest == Data(SHA256.hash(data: payload))
    }
}
