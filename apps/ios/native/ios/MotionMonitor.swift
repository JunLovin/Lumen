import CoreMotion

struct MotionSample {
    let acceleration: Double
    let yawRadians: Double
}

/// Unchecked: `manager` is only touched from `start`, and CoreMotion delivers on its own queue.
final class MotionMonitor: @unchecked Sendable {
    private static let updateInterval = 1.0 / 20
    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    func start() -> AsyncStream<MotionSample> {
        AsyncStream { continuation in
            guard manager.isDeviceMotionAvailable else {
                continuation.finish()
                return
            }
            manager.deviceMotionUpdateInterval = Self.updateInterval
            // Plan: the MacBook's magnets disturb the magnetometer, so yaw stays relative.
            manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { motion, _ in
                guard let motion else { return }
                let user = motion.userAcceleration
                let magnitude = (user.x * user.x + user.y * user.y + user.z * user.z).squareRoot()
                continuation.yield(MotionSample(acceleration: magnitude, yawRadians: motion.attitude.yaw))
            }
        }
    }
}
