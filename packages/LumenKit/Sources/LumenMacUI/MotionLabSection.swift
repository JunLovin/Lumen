#if os(macOS)
    import SwiftUI

    private struct Tunable {
        let name: String
        let initial: Float
        let range: ClosedRange<Float>
    }

    private let tunables = [
        Tunable(name: "glow.intensity", initial: DesignTokens.Glow.intensity, range: 0 ... 3),
        Tunable(name: "glow.bandFraction", initial: DesignTokens.Glow.bandFraction, range: 0.05 ... 1),
        Tunable(name: "glow.flowSpeed", initial: DesignTokens.Glow.flowSpeed, range: 0 ... 2),
        Tunable(name: "glow.noiseScale", initial: DesignTokens.Glow.noiseScale, range: 0.5 ... 10),
        Tunable(name: "effects.particleAmount", initial: DesignTokens.Effects.particleAmount, range: 0 ... 1),
        Tunable(name: "effects.particleCells", initial: DesignTokens.Effects.particleCells, range: 5 ... 60),
        Tunable(name: "effects.particleSpeed", initial: DesignTokens.Effects.particleSpeed, range: 0 ... 2),
        Tunable(name: "effects.bloom", initial: DesignTokens.Effects.bloom, range: 0 ... 4),
        Tunable(name: "ripple.seconds", initial: DesignTokens.Ripple.seconds, range: 0.3 ... 3),
        Tunable(name: "ripple.wavelengthPoints", initial: DesignTokens.Ripple.wavelengthPoints, range: 10 ... 120),
        Tunable(name: "ripple.intensity", initial: DesignTokens.Ripple.intensity, range: 0 ... 2),
        Tunable(name: "ripple.macRadiusPoints", initial: DesignTokens.Ripple.macRadiusPoints, range: 100 ... 1200),
        Tunable(
            name: "motion.springs.land.response",
            initial: Float(DesignTokens.Motion.land.response),
            range: 0.1 ... 1.5
        ),
        Tunable(
            name: "motion.springs.land.damping",
            initial: Float(DesignTokens.Motion.land.damping),
            range: 0.2 ... 1
        ),
    ]

    struct MotionLabSection: View {
        let model: LabModel

        var body: some View {
            Section {
                ForEach(tunables, id: \.name) { tunable in
                    let value = model.tuningValues[tunable.name] ?? tunable.initial
                    LabeledContent {
                        Slider(
                            value: Binding(
                                get: { value },
                                set: { model.tune(name: tunable.name, value: $0) }
                            ),
                            in: tunable.range
                        )
                    } label: {
                        Text(verbatim: "\(tunable.name) \(value.formatted(.number.precision(.fractionLength(2))))")
                    }
                }
            } header: {
                Text("lab.motion", bundle: .module)
            }
        }
    }

    extension LabModel {
        func applyTuning(name: String, value: Float) {
            tuningValues[name] = value
            mirror.tune(name: name, value: value)
        }

        func tune(name: String, value: Float) {
            applyTuning(name: name, value: value)
            let session = session
            Task { await session.sendTuning(name: name, value: value) }
        }
    }
#endif
