import LumenApplication
import LumenDomain

extension LabSession {
    private static let attemptsPerLocate = 2

    func consumeMotion() async {
        for await sample in motion.start() {
            currentYawRadians = sample.yawRadians
            if referenceYawRadians == nil {
                referenceYawRadians = sample.yawRadians
            }
            if settleDetector.observe(acceleration: sample.acceleration, atNanoseconds: clock.nowNanoseconds()) {
                settledAtNanoseconds = clock.nowNanoseconds()
                await link.send(.motionSettled)
            }
        }
    }

    func locate() async {
        guard !isLocating else {
            hasPendingLocate = true
            return
        }
        isLocating = true
        defer { isLocating = false }
        repeat {
            hasPendingLocate = false
            await measureWithRetry()
        } while hasPendingLocate
    }

    private func measureWithRetry() async {
        for _ in 0 ..< Self.attemptsPerLocate {
            do {
                _ = try await measurePlacement()
                lastLocationFailure = nil
                return
            } catch let error as PlacementError {
                lastLocationFailure = error
                guard error == .lowSignal else { return }
            } catch {
                lastLocationFailure = .microphoneUnavailable
                return
            }
        }
    }
}
