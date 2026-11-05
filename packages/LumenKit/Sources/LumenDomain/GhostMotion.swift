public struct SpringParameters: Sendable, Equatable {
    public let response: Double
    public let damping: Double

    public init(response: Double, damping: Double) {
        self.response = response
        self.damping = damping
    }
}

public struct SpringValue: Sendable, Equatable {
    private static let stepSeconds = 1.0 / 240

    public private(set) var position: Double
    public private(set) var velocity: Double

    public init(position: Double, velocity: Double) {
        self.position = position
        self.velocity = velocity
    }

    public mutating func advance(toward target: Double, parameters: SpringParameters, seconds: Double) {
        let frequency = 2 * Double.pi / parameters.response
        let stiffness = frequency * frequency
        let friction = 2 * parameters.damping * frequency
        var remaining = seconds
        while remaining > 0 {
            let step = min(remaining, Self.stepSeconds)
            velocity += (stiffness * (target - position) - friction * velocity) * step
            position += velocity * step
            remaining -= step
        }
    }

    public func isSettled(at target: Double, tolerance: Double) -> Bool {
        isSettled(at: target, within: tolerance, speed: tolerance)
    }

    public func isSettled(at target: Double, within distance: Double, speed: Double) -> Bool {
        abs(position - target) < distance && abs(velocity) < speed
    }
}

public struct GhostPose: Sendable, Equatable {
    public let center: MacPoint
    public let size: Double
    public let rotation: Double
    public let condensation: Double

    public init(center: MacPoint, size: Double, rotation: Double, condensation: Double) {
        self.center = center
        self.size = size
        self.rotation = rotation
        self.condensation = condensation
    }
}

public struct GhostLanding: Sendable, Equatable {
    public private(set) var x: SpringValue
    public private(set) var y: SpringValue
    public private(set) var condensation: SpringValue
    public let target: MacPoint
    public let size: Double
    public let rotation: Double
    private let parameters: SpringParameters
    // Past these values the remaining motion is invisible; waiting for rest added over half a second.
    private static let settlePoints = 1.5
    private static let settlePointsPerSecond = 30.0

    public init(from pose: GhostPose, velocity: MacPoint, target: MacPoint, parameters: SpringParameters) {
        x = SpringValue(position: pose.center.x, velocity: velocity.x)
        y = SpringValue(position: pose.center.y, velocity: velocity.y)
        condensation = SpringValue(position: pose.condensation, velocity: 0)
        self.target = target
        size = pose.size
        rotation = pose.rotation
        self.parameters = parameters
    }

    public mutating func advance(seconds: Double) -> GhostPose {
        x.advance(toward: target.x, parameters: parameters, seconds: seconds)
        y.advance(toward: target.y, parameters: parameters, seconds: seconds)
        condensation.advance(toward: 1, parameters: parameters, seconds: seconds)
        return GhostPose(
            center: MacPoint(x: x.position, y: y.position),
            size: size,
            rotation: rotation,
            condensation: min(max(condensation.position, 0), 1)
        )
    }

    public var isSettled: Bool {
        x.isSettled(at: target.x, within: Self.settlePoints, speed: Self.settlePointsPerSecond)
            && y.isSettled(at: target.y, within: Self.settlePoints, speed: Self.settlePointsPerSecond)
    }
}

public extension MacSpace {
    func ghostPose(for frame: InterpolatedFrame, phoneHeightMillimeters: Double) -> GhostPose {
        let size = size(millimeters: frame.objectWidth)
        let center = point(
            worldX: frame.worldX,
            worldY: frame.worldY,
            phoneHeightMillimeters: phoneHeightMillimeters,
            edge: frame.edge
        )
        let depth = frame.worldX * pointsPerMillimeter + size / 2
        return GhostPose(
            center: center,
            size: size,
            rotation: frame.rotation,
            condensation: size > 0 ? min(max(depth / size, 0), 1) : 0
        )
    }
}
