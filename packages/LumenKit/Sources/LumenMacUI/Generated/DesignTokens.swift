// Generated from packages/design-tokens/tokens.json. Do not edit.
public struct SpringToken: Sendable, Equatable {
    public let response: Double
    public let damping: Double
}

public enum DesignTokens {
    public enum Motion {
        public static let lift = SpringToken(response: 0.35, damping: 0.8)
        public static let follow = SpringToken(response: 0.18, damping: 0.9)
        public static let land = SpringToken(response: 0.5, damping: 0.72)
        public static let snapBack = SpringToken(response: 0.4, damping: 0.85)
        public static let glowBreathSeconds: Double = 3
    }
}
