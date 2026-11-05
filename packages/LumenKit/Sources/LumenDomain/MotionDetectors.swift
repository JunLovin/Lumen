public struct MotionSettleDetector: Sendable, Equatable {
    private let movingAcceleration: Double
    private let quietNanoseconds: UInt64
    private var quietSince: UInt64?
    private var hasMoved = false

    public init(movingAcceleration: Double, quietNanoseconds: UInt64) {
        self.movingAcceleration = movingAcceleration
        self.quietNanoseconds = quietNanoseconds
    }

    public mutating func observe(acceleration: Double, atNanoseconds now: UInt64) -> Bool {
        guard acceleration < movingAcceleration else {
            hasMoved = true
            quietSince = nil
            return false
        }
        guard hasMoved else { return false }
        let start = quietSince ?? now
        quietSince = start
        guard now - start >= quietNanoseconds else { return false }
        hasMoved = false
        quietSince = nil
        return true
    }
}

public struct DetachmentDetector: Sendable, Equatable {
    private let farRSSI: Int
    private let nearRSSI: Int
    private let requiredReadings: Int
    private var streak = 0
    public private(set) var isDetached = false

    public init(farRSSI: Int, nearRSSI: Int, requiredReadings: Int) {
        self.farRSSI = farRSSI
        self.nearRSSI = nearRSSI
        self.requiredReadings = requiredReadings
    }

    public mutating func observe(rssi: Int) -> Bool {
        let opposes = isDetached ? rssi > nearRSSI : rssi < farRSSI
        streak = opposes ? streak + 1 : 0
        if streak >= requiredReadings {
            isDetached.toggle()
            streak = 0
        }
        return isDetached
    }
}
