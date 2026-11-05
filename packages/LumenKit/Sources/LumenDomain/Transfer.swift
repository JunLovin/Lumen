public struct TransferResource: Sendable, Equatable {
    public let index: UInt32
    public let fileName: String
    public let byteCount: UInt64

    public init(index: UInt32, fileName: String, byteCount: UInt64) {
        self.index = index
        self.fileName = fileName
        self.byteCount = byteCount
    }
}

public struct TransferOffer: Sendable, Equatable {
    public let transferID: UInt32
    public let resources: [TransferResource]

    public init(transferID: UInt32, resources: [TransferResource]) {
        self.transferID = transferID
        self.resources = resources
    }

    public var totalBytes: UInt64 {
        resources.reduce(0) { $0 + $1.byteCount }
    }
}

public enum TransferStage: Sendable, Equatable {
    case preparing(fraction: Double)
    case receiving(receivedBytes: UInt64, totalBytes: UInt64)
    case completed(path: String, sha256Hex: String)
    case failed
    case cancelled
}

public struct TransferUpdate: Sendable, Equatable {
    public let transferID: UInt32
    public let stage: TransferStage

    public init(transferID: UInt32, stage: TransferStage) {
        self.transferID = transferID
        self.stage = stage
    }
}

public enum SafeFileName {
    private static let maximumLength = 255
    private static let forbidden: Set<Character> = ["/", "\\", ":", "\0"]

    /// Remote names are never trusted: only the last path component survives, and anything that
    /// could still walk out of the destination folder is rejected.
    public static func sanitize(_ name: String) -> String? {
        let normalized = name.map { $0 == "\\" ? "/" : $0 }
        let lastComponent = String(normalized).split(separator: "/", omittingEmptySubsequences: true).last
        guard let candidate = lastComponent.map(String.init),
              candidate != ".",
              candidate != "..",
              !candidate.hasPrefix("."),
              candidate.count <= maximumLength,
              !candidate.contains(where: forbidden.contains),
              !candidate.unicodeScalars.contains(where: { $0.value < 0x20 })
        else { return nil }
        return candidate
    }
}
