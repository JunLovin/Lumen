import Foundation
import LumenSignal

enum PlacementError: String, Error {
    case linkDown = "link_down"
    case lowSignal = "low_signal"
    case microphoneDenied = "microphone_denied"
    case microphoneUnavailable = "microphone_unavailable"
}

struct PlacementMeasurement {
    let estimate: AcousticEstimate
    let pairs: [ChirpPairArrival]
    let curve: [Float]
}

actor AcousticLocator {
    private static let pairsPerMeasurement = 3
    // Slightly over the plan's 300 ms: measured pairs ended about 350 ms into the recording.
    private static let recordingSeconds = 0.4
    private static let curvePointCount = 240

    private let recorder = MicrophoneRecorder()
    private var lastRecording: MicrophoneRecording?

    func measure(
        onCapturing: @Sendable () async -> Void,
        onPair: @Sendable (ChirpPairArrival) async -> Void
    ) async throws -> PlacementMeasurement {
        var pairs: [ChirpPairArrival] = []
        var curve: [Float] = []
        let parameters = ChirpParameters.initial
        for _ in 0 ..< Self.pairsPerMeasurement {
            let recording = try await record(onCapturing: onCapturing)
            let template = ChirpGenerator.chirp(parameters, sampleRate: recording.sampleRate)
            let envelope = MatchedFilter(template: template).envelope(of: recording.samples)
            curve = CorrelationCurve.downsample(envelope, pointCount: Self.curvePointCount)
            if let pair = ChirpPairEstimator.estimate(
                envelope: envelope,
                parameters: parameters,
                sampleRate: recording.sampleRate
            ) {
                pairs.append(pair)
                await onPair(pair)
            }
        }
        guard let estimate = AcousticEstimate(pairs: pairs, parameters: parameters) else {
            throw PlacementError.lowSignal
        }
        return PlacementMeasurement(estimate: estimate, pairs: pairs, curve: curve)
    }

    #if DEBUG
        func exportLastRecording() throws -> URL? {
            guard let lastRecording else { return nil }
            let rate = Int(lastRecording.sampleRate)
            let url = FileManager.default.temporaryDirectory
                .appending(path: "lumen-recording-\(rate)hz-\(UUID().uuidString).f32")
            let data = lastRecording.samples.withUnsafeBytes { Data($0) }
            try data.write(to: url)
            return url
        }
    #endif

    private func record(onCapturing: @Sendable () async -> Void) async throws -> MicrophoneRecording {
        do {
            let recording = try await recorder.record(seconds: Self.recordingSeconds, onCapturing: onCapturing)
            #if DEBUG
                lastRecording = recording
            #endif
            return recording
        } catch MicrophoneError.denied {
            throw PlacementError.microphoneDenied
        } catch {
            throw PlacementError.microphoneUnavailable
        }
    }
}
