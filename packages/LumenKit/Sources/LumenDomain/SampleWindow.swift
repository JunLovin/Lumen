public struct SampleWindow: Sendable, Equatable {
    private let capacity: Int
    private var values: [Double] = []
    private var nextIndex = 0

    public init(capacity: Int) {
        self.capacity = capacity
    }

    public mutating func add(_ value: Double) {
        if values.count < capacity {
            values.append(value)
        } else {
            values[nextIndex] = value
        }
        nextIndex = (nextIndex + 1) % capacity
    }

    public var count: Int {
        values.count
    }

    public func percentile(_ fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let position = Int((fraction * Double(sorted.count - 1)).rounded())
        return sorted[position]
    }
}
