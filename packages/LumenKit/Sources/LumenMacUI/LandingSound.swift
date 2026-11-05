#if os(macOS)
    import AVFoundation
    import LumenDomain

    @MainActor
    final class LandingSound {
        private static let sampleRate = 48000.0
        private let engine = AVAudioEngine()
        private let player = AVAudioPlayerNode()
        private var stopTask: Task<Void, Never>?

        init() {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: Self.format)
        }

        private static var format: AVAudioFormat? {
            AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        }

        func play(edge: PhoneEdge) {
            guard let buffer = Self.makeBuffer(), (try? engine.start()) != nil else { return }
            player.pan = edge == .right ? -DesignTokens.Sound.pan : DesignTokens.Sound.pan
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
            stopTask?.cancel()
            // A running engine would keep the audio hardware awake between landings.
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(DesignTokens.Sound.seconds * 2))
                guard !Task.isCancelled else { return }
                self?.player.stop()
                self?.engine.stop()
            }
        }

        private static func makeBuffer() -> AVAudioPCMBuffer? {
            let frames = AVAudioFrameCount(DesignTokens.Sound.seconds * sampleRate)
            guard
                let format,
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
                let samples = buffer.floatChannelData?[0]
            else { return nil }
            buffer.frameLength = frames
            for frame in 0 ..< Int(frames) {
                let time = Double(frame) / sampleRate
                let progress = time / DesignTokens.Sound.seconds
                let attack = min(progress * 40, 1)
                let decay = pow(1 - progress, 3)
                let tone = sin(2 * .pi * DesignTokens.Sound.frequencyHz * time)
                let overtone = 0.3 * sin(2 * .pi * DesignTokens.Sound.frequencyHz * 2.01 * time)
                samples[frame] = Float((tone + overtone) * attack * decay) * DesignTokens.Sound.gain
            }
            return buffer
        }
    }
#endif
