import LumenApplication
import LumenDomain
import LumenMacUI
import LumenProximity
import LumenTransport
import SwiftUI

@main
struct LumenApp: App {
    private let readProtocolVersion = ReadProtocolVersion(protocolInfo: ProtocolInfoAdapter())
    @State private var labModel: LabModel
    @State private var pairingModel: PairingModel

    init() {
        let link = MacSecureLink(version: ProtocolInfoAdapter().localProtocolVersion)
        let clock = SystemClockAdapter()
        let amplitude = DesignTokens.Chirp.defaultAmplitude
        let session = PeerLabSession(
            link: link,
            clock: clock,
            chirpPlayer: ChirpPlayerAdapter(),
            chirpAmplitude: amplitude
        )
        let model = LabModel(session: session, clock: clock, chirpAmplitude: amplitude)
        let pairing = PairingModel(useCase: PairNearbyDevice(
            trustStore: KeychainTrustStore(service: "com.junlovin.lumen.mac"),
            identityFactory: IdentityFactoryAdapter(),
            pairing: PairingResponder(),
            proximity: MacProximityScanner(),
            link: link,
            clock: clock,
            deviceName: Host.current().localizedName ?? "Mac",
            detector: NearbyDetector(
                minimumRSSI: ProximityService.nearRSSI,
                dwellNanoseconds: ProximityService.nearDwellNanoseconds
            )
        ))
        _labModel = State(initialValue: model)
        _pairingModel = State(initialValue: pairing)
        Task { await model.setListening(link.start()) }
        Task { await session.run() }
        Task { await model.consumeUpdates() }
        Task { await pairing.run() }
    }

    var body: some Scene {
        MenuBarExtra("Lumen", systemImage: "sparkles") {
            MenuBarContentView(readProtocolVersion: readProtocolVersion, pairing: pairingModel)
        }
        #if DEBUG
            Window("Lumen Lab", id: LabWindow.identifier) {
                LabView(model: labModel, pairing: pairingModel)
            }
            .defaultLaunchBehavior(.suppressed)
        #endif
    }
}
