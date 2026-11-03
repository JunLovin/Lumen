// Generated from packages/design-tokens/tokens.json. Do not edit.
public struct SpringToken: Sendable, Equatable {
    public let response: Double
    public let damping: Double
}

public struct ColorToken: Sendable, Equatable {
    public let red: Float
    public let green: Float
    public let blue: Float
}

public enum DesignTokens {
    public enum Motion {
        public static let lift = SpringToken(response: 0.35, damping: 0.8)
        public static let follow = SpringToken(response: 0.18, damping: 0.9)
        public static let land = SpringToken(response: 0.5, damping: 0.72)
        public static let snapBack = SpringToken(response: 0.4, damping: 0.85)
        public static let glowBreathSeconds: Double = 3
    }

    public enum Glow {
        public static let overlayWidthPoints: Double = 160
        public static let bandFraction: Float = 0.45
        public static let intensity: Float = 1.1
        public static let flowSpeed: Float = 0.35
        public static let noiseScale: Float = 3.2
        public static let primary = ColorToken(red: 0.42, green: 0.62, blue: 1)
        public static let secondary = ColorToken(red: 0.78, green: 0.45, blue: 1)
        public static let highlight = ColorToken(red: 1, green: 0.86, blue: 0.72)
    }

    public enum Pairing {
        public static let ringCycleSeconds: Double = 1.6
        public static let ringCount = 3
        public static let verificationPalette = [
            ColorToken(red: 1, green: 0.35, blue: 0.35),
            ColorToken(red: 1, green: 0.72, blue: 0.2),
            ColorToken(red: 0.3, green: 0.85, blue: 0.45),
            ColorToken(red: 0.25, green: 0.75, blue: 1),
            ColorToken(red: 0.55, green: 0.45, blue: 1),
            ColorToken(red: 1, green: 0.45, blue: 0.8),
        ]
    }

    public enum Placement {
        public static let cometSeconds: Double = 1.2
        public static let cometLengthFraction: Double = 0.18
        public static let cometWidthPoints: Double = 6
    }

    public enum Chirp {
        public static let defaultAmplitude: Float = 0.25
    }
}
