public struct TimedDragFrame: Sendable, Equatable {
    public let sample: DragFrameSample
    public let localTimestampNs: UInt64

    public init(sample: DragFrameSample, localTimestampNs: UInt64) {
        self.sample = sample
        self.localTimestampNs = localTimestampNs
    }
}

public struct InterpolatedFrame: Sendable, Equatable {
    public let worldX: Double
    public let worldY: Double
    public let velocityX: Double
    public let velocityY: Double
    public let edgeProximity: Double
    public let rotation: Double
    public let objectWidth: Double
    public let edge: PhoneEdge

    public init(
        worldX: Double,
        worldY: Double,
        velocityX: Double,
        velocityY: Double,
        edgeProximity: Double,
        rotation: Double,
        objectWidth: Double,
        edge: PhoneEdge
    ) {
        self.worldX = worldX
        self.worldY = worldY
        self.velocityX = velocityX
        self.velocityY = velocityY
        self.edgeProximity = edgeProximity
        self.rotation = rotation
        self.objectWidth = objectWidth
        self.edge = edge
    }
}

public struct FrameInterpolator: Sendable, Equatable {
    private static let capacity = 32
    private static let nanosecondsPerSecond = 1_000_000_000.0

    private let maximumExtrapolationNanoseconds: UInt64
    private var frames: [TimedDragFrame] = []

    public init(maximumExtrapolationNanoseconds: UInt64) {
        self.maximumExtrapolationNanoseconds = maximumExtrapolationNanoseconds
    }

    public mutating func add(_ frame: TimedDragFrame) {
        guard let last = frames.last, frame.localTimestampNs < last.localTimestampNs else {
            frames.append(frame)
            trim()
            return
        }
        let index = frames.firstIndex { $0.localTimestampNs > frame.localTimestampNs } ?? frames.endIndex
        frames.insert(frame, at: index)
        trim()
    }

    public mutating func reset() {
        frames.removeAll()
    }

    public var newest: TimedDragFrame? {
        frames.last
    }

    public func frame(atNanoseconds time: UInt64) -> InterpolatedFrame? {
        guard let first = frames.first, let last = frames.last else { return nil }
        if time <= first.localTimestampNs {
            return Self.values(first)
        }
        if time >= last.localTimestampNs {
            return extrapolated(from: last, to: time)
        }
        guard let upperIndex = frames.firstIndex(where: { $0.localTimestampNs >= time }), upperIndex > 0 else {
            return Self.values(last)
        }
        let lower = frames[upperIndex - 1]
        let upper = frames[upperIndex]
        let span = Double(upper.localTimestampNs - lower.localTimestampNs)
        let progress = span > 0 ? Double(time - lower.localTimestampNs) / span : 1
        return Self.mix(Self.values(lower), Self.values(upper), progress)
    }

    private func extrapolated(from frame: TimedDragFrame, to time: UInt64) -> InterpolatedFrame {
        let elapsed = min(time - frame.localTimestampNs, maximumExtrapolationNanoseconds)
        let seconds = Double(elapsed) / Self.nanosecondsPerSecond
        let values = Self.values(frame)
        return InterpolatedFrame(
            worldX: values.worldX + values.velocityX * seconds,
            worldY: values.worldY + values.velocityY * seconds,
            velocityX: values.velocityX,
            velocityY: values.velocityY,
            edgeProximity: values.edgeProximity,
            rotation: values.rotation,
            objectWidth: values.objectWidth,
            edge: values.edge
        )
    }

    private mutating func trim() {
        if frames.count > Self.capacity {
            frames.removeFirst()
        }
    }

    private static func values(_ frame: TimedDragFrame) -> InterpolatedFrame {
        let sample = frame.sample
        return InterpolatedFrame(
            worldX: Double(sample.xMillimeters),
            worldY: Double(sample.yMillimeters),
            velocityX: Double(sample.velocityXMillimetersPerSecond),
            velocityY: Double(sample.velocityYMillimetersPerSecond),
            edgeProximity: Double(sample.edgeProximity),
            rotation: Double(sample.rotationRadians),
            objectWidth: Double(sample.objectWidthMillimeters),
            edge: sample.edge
        )
    }

    private static func mix(
        _ lower: InterpolatedFrame,
        _ upper: InterpolatedFrame,
        _ progress: Double
    ) -> InterpolatedFrame {
        let blend = { (start: Double, end: Double) in start + (end - start) * progress }
        return InterpolatedFrame(
            worldX: blend(lower.worldX, upper.worldX),
            worldY: blend(lower.worldY, upper.worldY),
            velocityX: blend(lower.velocityX, upper.velocityX),
            velocityY: blend(lower.velocityY, upper.velocityY),
            edgeProximity: blend(lower.edgeProximity, upper.edgeProximity),
            rotation: blend(lower.rotation, upper.rotation),
            objectWidth: blend(lower.objectWidth, upper.objectWidth),
            edge: upper.edge
        )
    }
}
