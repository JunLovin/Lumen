#if os(macOS)
    import CoreAudio
    import LumenApplication

    public struct AudioRouteAdapter: AudioRoutePort {
        public init() {}

        public func canPlayUltrasound() async -> Bool {
            guard let device = defaultOutputDevice() else { return false }
            return transportType(of: device) == kAudioDeviceTransportTypeBuiltIn && !isMuted(device)
        }

        private func defaultOutputDevice() -> AudioDeviceID? {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var device = AudioDeviceID(0)
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            let status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
            )
            return status == noErr ? device : nil
        }

        private func transportType(of device: AudioDeviceID) -> UInt32? {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transport = UInt32(0)
            var size = UInt32(MemoryLayout<UInt32>.size)
            let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport)
            return status == noErr ? transport : nil
        }

        private func isMuted(_ device: AudioDeviceID) -> Bool {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var muted = UInt32(0)
            var size = UInt32(MemoryLayout<UInt32>.size)
            let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted)
            return status == noErr && muted != 0
        }
    }
#endif
