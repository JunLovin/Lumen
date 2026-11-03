#if os(macOS)
    import LumenApplication
    import LumenDomain
    import Observation

    @MainActor
    @Observable
    public final class PairingModel {
        public private(set) var stage: PairingStage = .idle
        public private(set) var signalStrength: Int?
        @ObservationIgnored private let useCase: PairNearbyDevice
        @ObservationIgnored private var panel: PairingPanel?

        public init(useCase: PairNearbyDevice) {
            self.useCase = useCase
        }

        public var pairedDeviceName: String? {
            if case let .paired(device) = stage {
                return device.name
            }
            return nil
        }

        public func run() async {
            let signal = useCase.signalStrength
            Task { [weak self] in
                for await rssi in signal {
                    self?.signalStrength = rssi
                }
            }
            await useCase.start()
            for await stage in useCase.stages {
                apply(stage)
            }
        }

        public func confirm() {
            let useCase = useCase
            Task { await useCase.confirm() }
        }

        public func reject() {
            let useCase = useCase
            Task { await useCase.reject() }
        }

        public func forget() {
            let useCase = useCase
            Task { await useCase.forget() }
        }

        private func apply(_ stage: PairingStage) {
            self.stage = stage
            switch stage {
            case .exchanging, .awaitingConfirmation:
                if panel == nil {
                    panel = PairingPanel(model: self)
                }
                panel?.show()
            case .idle, .searching, .paired, .failed:
                panel?.hide()
            }
        }
    }
#endif
