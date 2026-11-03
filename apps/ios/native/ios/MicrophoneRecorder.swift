import AVFoundation

enum MicrophoneError: Error {
    case denied
    case unavailable
}

struct MicrophoneRecording {
    let samples: [Float]
    let sampleRate: Double
}

actor MicrophoneRecorder {
    private static let preferredSampleRate = 48000.0
    private static let tapBufferFrames: AVAudioFrameCount = 1024

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func record(seconds: Double, onCapturing: @Sendable () async -> Void) async throws -> MicrophoneRecording {
        guard await requestPermission() else { throw MicrophoneError.denied }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setPreferredSampleRate(Self.preferredSampleRate)
        try session.setActive(true)
        defer { try? session.setActive(false, options: .notifyOthersOnDeactivation) }

        let engine = AVAudioEngine()
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw MicrophoneError.unavailable }
        let (stream, continuation) = AsyncStream.makeStream(of: [Float].self)
        engine.inputNode.installTap(onBus: 0, bufferSize: Self.tapBufferFrames, format: format) { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            continuation.yield(Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))))
        }
        try engine.start()
        defer {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }

        let targetCount = Int(seconds * format.sampleRate)
        var samples: [Float] = []
        samples.reserveCapacity(targetCount)
        var hasSignaled = false
        for await chunk in stream {
            samples.append(contentsOf: chunk)
            if !hasSignaled {
                hasSignaled = true
                await onCapturing()
            }
            if samples.count >= targetCount {
                break
            }
        }
        return MicrophoneRecording(samples: samples, sampleRate: format.sampleRate)
    }
}
