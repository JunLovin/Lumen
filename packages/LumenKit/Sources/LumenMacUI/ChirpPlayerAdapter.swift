#if os(macOS)
    import AVFoundation
    import LumenApplication
    import LumenSignal

    public actor ChirpPlayerAdapter: ChirpPlayerPort {
        private static let sampleRate = 48000.0
        private static let testToneFrequencyHz = 1000.0
        private static let testToneSeconds = 0.5
        private let engine = AVAudioEngine()
        private let player = AVAudioPlayerNode()
        private var format: AVAudioFormat?

        public init() {}

        public func playPair(amplitude: Float) {
            guard let format = prepareEngine() else { return }
            let pair = ChirpGenerator.stereoPair(.initial, sampleRate: Self.sampleRate, amplitude: amplitude)
            play(left: pair.left, right: pair.right, format: format)
        }

        public func playTestTone(on channel: AudioChannel) {
            guard let format = prepareEngine() else { return }
            let tone = ChirpGenerator.testTone(
                frequencyHz: Self.testToneFrequencyHz,
                seconds: Self.testToneSeconds,
                sampleRate: Self.sampleRate,
                amplitude: DesignTokens.Chirp.defaultAmplitude
            )
            let silence = [Float](repeating: 0, count: tone.count)
            switch channel {
            case .left:
                play(left: tone, right: silence, format: format)
            case .right:
                play(left: silence, right: tone, format: format)
            }
        }

        private func play(left: [Float], right: [Float], format: AVAudioFormat) {
            guard
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(left.count)),
                let channels = buffer.floatChannelData
            else { return }
            buffer.frameLength = buffer.frameCapacity
            channels[0].update(from: left, count: left.count)
            channels[1].update(from: right, count: right.count)
            player.scheduleBuffer(buffer, completionHandler: nil)
            player.play()
        }

        private func prepareEngine() -> AVAudioFormat? {
            if let format, engine.isRunning {
                return format
            }
            guard let stereo = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 2) else {
                return nil
            }
            if format == nil {
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: stereo)
            }
            guard (try? engine.start()) != nil else { return nil }
            format = stereo
            return stereo
        }
    }
#endif
