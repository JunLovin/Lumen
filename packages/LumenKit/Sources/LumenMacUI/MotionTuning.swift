#if os(macOS)
    struct MotionTuning {
        var bandFraction = DesignTokens.Glow.bandFraction
        var intensity = DesignTokens.Glow.intensity
        var flowSpeed = DesignTokens.Glow.flowSpeed
        var noiseScale = DesignTokens.Glow.noiseScale
        var particleAmount = DesignTokens.Effects.particleAmount
        var particleCells = DesignTokens.Effects.particleCells
        var particleSpeed = DesignTokens.Effects.particleSpeed
        var bloom = DesignTokens.Effects.bloom
        var landResponse = DesignTokens.Motion.land.response
        var landDamping = DesignTokens.Motion.land.damping

        /// Names are paths in tokens.json, so the values exported from the lab map back onto it.
        mutating func set(name: String, value: Float) {
            switch name {
            case "glow.bandFraction": bandFraction = value
            case "glow.intensity": intensity = value
            case "glow.flowSpeed": flowSpeed = value
            case "glow.noiseScale": noiseScale = value
            case "effects.particleAmount": particleAmount = value
            case "effects.particleCells": particleCells = value
            case "effects.particleSpeed": particleSpeed = value
            case "effects.bloom": bloom = value
            case "motion.springs.land.response": landResponse = Double(value)
            case "motion.springs.land.damping": landDamping = Double(value)
            default: break
            }
        }
    }
#endif
