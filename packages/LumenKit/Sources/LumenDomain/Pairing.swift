public struct VerificationPattern: Sendable, Equatable {
    public static let length = 4
    public static let paletteSize: UInt8 = 6

    public let colorIndices: [Int]

    public init?(hash: [UInt8]) {
        guard hash.count >= Self.length else { return nil }
        colorIndices = hash.prefix(Self.length).map { Int($0 % Self.paletteSize) }
    }
}

public enum PairingFailure: Sendable, Equatable {
    case connectionLost
    case verificationFailed
    case rejected
}

public enum PairingStage: Sendable, Equatable {
    case idle
    case searching
    case exchanging
    case awaitingConfirmation(VerificationPattern)
    case paired(PairedDevice)
    case failed(PairingFailure)
}

public struct NearbyDetector: Sendable, Equatable {
    private let minimumRSSI: Int
    private let dwellNanoseconds: UInt64
    private var nearSince: UInt64?

    public init(minimumRSSI: Int, dwellNanoseconds: UInt64) {
        self.minimumRSSI = minimumRSSI
        self.dwellNanoseconds = dwellNanoseconds
    }

    public mutating func observe(rssi: Int, atNanoseconds now: UInt64) -> Bool {
        guard rssi >= minimumRSSI else {
            nearSince = nil
            return false
        }
        let start = nearSince ?? now
        nearSince = start
        return now - start >= dwellNanoseconds
    }
}

public struct ReconnectBackoff: Sendable, Equatable {
    private let initialMilliseconds: Int
    private let maximumMilliseconds: Int
    private var attempt = 0

    public init(initialMilliseconds: Int, maximumMilliseconds: Int) {
        self.initialMilliseconds = initialMilliseconds
        self.maximumMilliseconds = maximumMilliseconds
    }

    public mutating func nextDelayMilliseconds() -> Int {
        let delay = min(initialMilliseconds << min(attempt, 16), maximumMilliseconds)
        attempt += 1
        return delay
    }

    public mutating func reset() {
        attempt = 0
    }
}
