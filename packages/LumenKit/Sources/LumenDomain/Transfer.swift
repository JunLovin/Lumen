public struct TransferResource: Sendable, Equatable {
    public let index: UInt32
    public let fileName: String
    public let byteCount: UInt64
    public let isDirectory: Bool

    public init(index: UInt32, fileName: String, byteCount: UInt64, isDirectory: Bool = false) {
        self.index = index
        self.fileName = fileName
        self.byteCount = byteCount
        self.isDirectory = isDirectory
    }
}

public struct TransferOffer: Sendable, Equatable {
    public let transferID: UInt32
    public let resources: [TransferResource]
    public let isDirect: Bool

    public init(transferID: UInt32, resources: [TransferResource], isDirect: Bool = false) {
        self.transferID = transferID
        self.resources = resources
        self.isDirect = isDirect
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

public enum SafeRelativePath {
    private static let maximumComponentLength = 255
    private static let maximumDepth = 64
    private static let forbidden: Set<Character> = ["\\", ":", "\0"]

    /// Remote paths are never trusted: anything that could walk out of the destination is rejected
    /// outright rather than repaired, so a hostile name can never land somewhere unexpected.
    public static func components(of path: String) -> [String]? {
        guard !path.hasPrefix("/"), !path.hasSuffix("/"), !path.isEmpty else { return nil }
        let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard components.count <= maximumDepth, components.allSatisfy(isSafe) else { return nil }
        return components
    }

    private static func isSafe(_ component: String) -> Bool {
        !component.isEmpty
            && component != "."
            && component != ".."
            && component.count <= maximumComponentLength
            && !component.contains(where: forbidden.contains)
            && !component.unicodeScalars.contains { $0.value < 0x20 }
    }
}
