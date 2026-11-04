#if os(macOS)
    import CoreGraphics
    import Foundation
    import Observation

    @MainActor
    @Observable
    public final class EffectSettings {
        private static let soundKey = "effects.sound"
        private static let lensKey = "effects.lens"

        public var isSoundEnabled: Bool {
            didSet { UserDefaults.standard.set(isSoundEnabled, forKey: Self.soundKey) }
        }

        public var isLensEnabled: Bool {
            didSet {
                UserDefaults.standard.set(isLensEnabled, forKey: Self.lensKey)
                if isLensEnabled, !CGPreflightScreenCaptureAccess() {
                    CGRequestScreenCaptureAccess()
                }
            }
        }

        public init() {
            isSoundEnabled = UserDefaults.standard.bool(forKey: Self.soundKey)
            isLensEnabled = UserDefaults.standard.bool(forKey: Self.lensKey)
        }
    }
#endif
