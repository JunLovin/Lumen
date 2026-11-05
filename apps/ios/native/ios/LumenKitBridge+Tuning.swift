import Foundation

public extension LumenKitBridge {
    private static var onboardingKey: String {
        "onboarding.seen"
    }

    @objc func sendTuning(name: String, value: Double) {
        let session = session
        Task { await session.setTuning(name: name, value: value) }
    }

    @objc func readTuning(_ completion: @escaping @Sendable (NSDictionary) -> Void) {
        let session = session
        Task { await completion(session.tuning as NSDictionary) }
    }

    @objc func hasSeenOnboarding() -> Bool {
        UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }

    @objc func markOnboardingSeen() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
    }
}

extension LabSession {
    func setTuning(name: String, value: Double) async {
        tuning[name] = value
        await send(.tuneToken(name: name, value: Float(value)))
    }
}
