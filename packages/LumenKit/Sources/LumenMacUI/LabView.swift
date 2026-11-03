#if os(macOS)
    import LumenDomain
    import SwiftUI

    public struct LabView: View {
        private let model: LabModel
        private let pairing: PairingModel

        public init(model: LabModel, pairing: PairingModel) {
            self.model = model
            self.pairing = pairing
        }

        public var body: some View {
            HStack(alignment: .top, spacing: 16) {
                DragPreview(model: model)
                Form {
                    ConnectionSection(model: model, pairing: pairing)
                    PlacementSection(model: model)
                    LatencySection(model: model)
                    AcousticSection(model: model)
                    OverlaySection(model: model)
                }
                .formStyle(.grouped)
            }
            .padding()
            .frame(minWidth: 680, minHeight: 620)
        }
    }

    private struct DragPreview: View {
        private static let phoneSizeMillimeters = CGSize(width: 64.6, height: 139.8)
        let model: LabModel

        var body: some View {
            TimelineView(.animation) { context in
                Canvas { graphics, size in
                    graphics.stroke(
                        Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 16),
                        with: .color(.secondary)
                    )
                    guard let frame = model.latestFrame else { return }
                    let scale = size.width / Self.phoneSizeMillimeters.width
                    let center = CGPoint(x: CGFloat(frame.xMillimeters) * scale, y: CGFloat(frame.yMillimeters) * scale)
                    let radius = CGFloat(frame.objectWidthMillimeters) * scale / 2
                    let dot = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    graphics.fill(Path(ellipseIn: dot), with: .color(.accentColor))
                }
                .onChange(of: context.date) { model.renderTick() }
            }
            .aspectRatio(Self.phoneSizeMillimeters.width / Self.phoneSizeMillimeters.height, contentMode: .fit)
            .frame(width: 240)
        }
    }

    private struct ConnectionSection: View {
        let model: LabModel
        let pairing: PairingModel

        var body: some View {
            Section {
                LabRow("lab.listening", yesNo(model.isListening))
                LabRow("lab.connected", yesNo(model.isConnected))
                LabRow("lab.rssi", pairing.signalStrength.map { "\($0) dBm" } ?? "—")
                LabRow("lab.clockRoundTrip", milliseconds(model.clockRoundTripMilliseconds))
            }
        }
    }

    private struct PlacementSection: View {
        let model: LabModel

        var body: some View {
            Section {
                LabRow("lab.side", model.placement.map { String(describing: $0.side) } ?? "—")
                LabRow("lab.confidence", model.placement.map { String(format: "%.0f %%", $0.confidence * 100) } ?? "—")
                LabRow("lab.detached", model.placement.map { yesNo($0.isDetached) } ?? "—")
                LabRow("lab.ultrasoundRoute", model.canPlayUltrasound.map(yesNo) ?? "—")
                ForEach(PlacementSide.allCases, id: \.self) { side in
                    ProgressView(value: model.placement?.distribution.probability(of: side) ?? 0) {
                        Text(String(describing: side))
                    }
                }
                LabRow("lab.history", model.placementHistory.joined(separator: ", "))
            }
        }
    }

    private struct LatencySection: View {
        let model: LabModel

        var body: some View {
            Section {
                LabRow("lab.networkP50", milliseconds(model.networkLatency?.p50))
                LabRow("lab.networkP95", milliseconds(model.networkLatency?.p95))
                LabRow("lab.renderP50", milliseconds(model.renderLatency?.p50))
                LabRow("lab.renderP95", milliseconds(model.renderLatency?.p95))
                LabRow("lab.gapP95", milliseconds(model.frameGap?.p95))
                LabRow("lab.gapMax", milliseconds(model.frameGap?.max))
                LabRow("lab.framesReceived", String(model.receivedFrames))
                LabRow("lab.framesLost", String(model.lostFrames))
                Button { model.resetStats() } label: { Text("lab.reset", bundle: .module) }
            }
        }
    }

    private struct AcousticSection: View {
        let model: LabModel

        var body: some View {
            @Bindable var model = model
            Section {
                LabRow("lab.tau", model.acousticReading.map { String(format: "%.0f µs", $0.tauMicroseconds) } ?? "—")
                LabRow(
                    "lab.level",
                    model.acousticReading.map { String(format: "%.1f dB", $0.levelDifferenceDecibels) } ?? "—"
                )
                LabRow("lab.snr", model.acousticReading.map { String(format: "%.1f dB", $0.snrDecibels) } ?? "—")
                Slider(value: $model.chirpAmplitude, in: 0.02 ... 1) {
                    Text("lab.chirpAmplitude", bundle: .module)
                }
                HStack {
                    Button { model.playTestTone(on: .left) } label: { Text("lab.toneLeft", bundle: .module) }
                    Button { model.playTestTone(on: .right) } label: { Text("lab.toneRight", bundle: .module) }
                }
            }
        }
    }

    private struct OverlaySection: View {
        let model: LabModel

        var body: some View {
            @Bindable var model = model
            Section {
                Button { model.toggleOverlay() } label: { Text("lab.toggleOverlay", bundle: .module) }
                Slider(value: $model.manualProximity, in: 0 ... 1) {
                    Text("lab.proximity", bundle: .module)
                }
                LabRow("lab.gpuP50", milliseconds(model.gpuTime?.p50, decimals: 2))
                LabRow("lab.gpuP95", milliseconds(model.gpuTime?.p95, decimals: 2))
            }
        }
    }

    private struct LabRow: View {
        private let label: LocalizedStringKey
        private let value: String

        init(_ label: LocalizedStringKey, _ value: String) {
            self.label = label
            self.value = value
        }

        var body: some View {
            LabeledContent {
                Text(value).monospacedDigit()
            } label: {
                Text(label, bundle: .module)
            }
        }
    }

    private func yesNo(_ value: Bool) -> String {
        String(localized: value ? "common.yes" : "common.no", bundle: .module)
    }

    private func milliseconds(_ value: Double?, decimals: Int = 1) -> String {
        value.map { String(format: "%.\(decimals)f ms", $0) } ?? "—"
    }
#endif
