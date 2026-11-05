import Foundation
import Network

public extension PhoneSecureLink {
    private static var uploadAttempts: Int {
        8
    }

    private static var uploadRetryDelay: Duration {
        .seconds(1)
    }

    func probeFileChannel() async -> Bool {
        guard let fileEndpoint, let filePSK else { return false }
        let connection = NWConnection(to: fileEndpoint, using: SecureParameters.stream(psk: filePSK))
        return await FileProbe.run(on: FramedConnection(connection: connection))
    }

    func upload(
        fileAt url: URL,
        transferID: UInt32,
        resourceIndex: UInt32,
        progress: @escaping @Sendable (UInt64) -> Void
    ) async throws {
        for attempt in 0 ..< Self.uploadAttempts {
            try Task.checkCancellation()
            if attempt > 0 {
                try await Task.sleep(for: Self.uploadRetryDelay)
            }
            guard let fileEndpoint, let filePSK else { continue }
            let channel = FramedConnection(
                connection: NWConnection(to: fileEndpoint, using: SecureParameters.stream(psk: filePSK))
            )
            if try await FileUploader.upload(
                fileAt: url,
                transferID: transferID,
                resourceIndex: resourceIndex,
                channel: channel,
                progress: progress
            ) {
                return
            }
        }
        throw ChannelError.closed
    }
}
