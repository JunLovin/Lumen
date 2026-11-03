#if os(macOS)
    import AVFoundation
    import LumenApplication
    import LumenSignal

    public actor ChirpPlayerAdapter: ChirpPlayerPort {
        private static let sampleRate = 48000.0
        private let engine = AVAudioEngine()
        private let player = AVAudioPlayerNode()
        private var format: AVAudioFormat?

        public init() {}

        public func playPair(amplitude: Float) {
            guard let format = prepareEngine() else { return }
            let pair = ChirpGenerator.stereoPair(.initial, sampleRate: Self.sampleRate, amplitude: amplitude)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(pair.left.count))
            else { return }
            buffer.frameLength = buffer.frameCapacity
            guard let channels = buffer.floatChannelData else { return }
            pair.left.withUnsafeBufferPointer { channels[0].update(from: $0.baseAddress!, count: $0.count) }
            pair.right.withUnsafeBufferPointer { channels[1].update(from: $0.baseAddress!, count: $0.count) }
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
