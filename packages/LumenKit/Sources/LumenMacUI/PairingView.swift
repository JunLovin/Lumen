#if os(macOS)
    import LumenDomain
    import SwiftUI

    struct PairingView: View {
        let model: PairingModel

        var body: some View {
            VStack(spacing: 20) {
                Text("pairing.title", bundle: .module).font(.title2.bold())
                content
            }
            .padding(32)
            .frame(width: 360, height: 420)
        }

        @ViewBuilder private var content: some View {
            if case let .awaitingConfirmation(pattern) = model.stage {
                VerificationRing(colorIndices: pattern.colorIndices).frame(width: 160, height: 160)
                Text("pairing.compare", bundle: .module).multilineTextAlignment(.center)
                HStack {
                    Button { model.reject() } label: { Text("pairing.reject", bundle: .module) }
                    Button { model.confirm() } label: { Text("pairing.confirm", bundle: .module) }
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                ConvergingRings().frame(width: 160, height: 160)
                Text("pairing.exchanging", bundle: .module)
            }
        }
    }

    struct VerificationRing: View {
        let colorIndices: [Int]

        var body: some View {
            Canvas { graphics, size in
                let palette = DesignTokens.Pairing.verificationPalette
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let lineWidth = size.width / 8
                let radius = (size.width - lineWidth) / 2
                let sweep = 360.0 / Double(max(colorIndices.count, 1))
                for (position, index) in colorIndices.enumerated() {
                    let start = Double(position) * sweep - 90
                    var arc = Path()
                    arc.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(start),
                        endAngle: .degrees(start + sweep),
                        clockwise: false
                    )
                    let token = palette[index % palette.count]
                    let color = Color(red: Double(token.red), green: Double(token.green), blue: Double(token.blue))
                    graphics.stroke(arc, with: .color(color), lineWidth: lineWidth)
                }
            }
        }
    }

    struct ConvergingRings: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            TimelineView(.animation(paused: reduceMotion)) { context in
                Canvas { graphics, size in
                    let cycle = DesignTokens.Pairing.ringCycleSeconds
                    let count = DesignTokens.Pairing.ringCount
                    let time = context.date.timeIntervalSinceReferenceDate
                    for ring in 0 ..< count {
                        let phase = (time / cycle + Double(ring) / Double(count)).truncatingRemainder(dividingBy: 1)
                        let scale = 1 - phase
                        let side = size.width * scale
                        let rect = CGRect(
                            x: (size.width - side) / 2,
                            y: (size.height - side) / 2,
                            width: side,
                            height: side
                        )
                        graphics.stroke(Path(ellipseIn: rect), with: .color(.accentColor.opacity(phase)), lineWidth: 2)
                    }
                }
            }
        }
    }
#endif
