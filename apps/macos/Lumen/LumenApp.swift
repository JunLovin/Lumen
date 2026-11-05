import LumenApplication
import LumenDomain
import LumenMacUI
import LumenProximity
import LumenTransport
import SwiftUI

@main
struct LumenApp: App {
    private let readProtocolVersion = ReadProtocolVersion(protocolInfo: ProtocolInfoAdapter())
    private let destination: DestinationFolder
    private let settings: EffectSettings
    @State private var labModel: LabModel
    @State private var pairingModel: PairingModel

    init() {
        let sink = TemporaryFileSink(root: FileManager.default.temporaryDirectory.appending(path: "Lumen"))
        let source = FileBatchStore()
        let link = MacSecureLink(version: ProtocolInfoAdapter().localProtocolVersion, sink: sink, source: source)
        let destinationFolder = DestinationFolder()
        let effectSettings = EffectSettings()
        let clock = SystemClockAdapter()
        let amplitude = DesignTokens.Chirp.defaultAmplitude
        let session = PeerLabSession(
            link: link,
            clock: clock,
            chirpPlayer: ChirpPlayerAdapter(),
            audioRoute: AudioRouteAdapter(),
            placementStore: UserDefaultsPlacementStore(),
            fileSink: sink,
            fileSource: source,
            chirpAmplitude: amplitude
        )
        let model = LabModel(
            session: session,
            clock: clock,
            destination: destinationFolder,
            settings: effectSettings,
            chirpAmplitude: amplitude
        )
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
        destination = destinationFolder
        settings = effectSettings
        _pairingModel = State(initialValue: pairing)
        Task { await model.setListening(link.start()) }
        Task { await session.run() }
        Task { await model.consumeUpdates() }
        Task { await pairing.run() }
        Task { @MainActor in OnboardingPanel.showIfNeeded() }
        Task {
            for await rssi in await MacProximityScanner().rssiReadings() {
                await session.observe(rssi: rssi)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra("Lumen", systemImage: "sparkles") {
            MenuBarContentView(
                readProtocolVersion: readProtocolVersion,
                pairing: pairingModel,
                destination: destination,
                model: labModel,
                settings: settings
            )
        }
        #if DEBUG
            Window("Lumen Lab", id: LabWindow.identifier) {
                LabView(model: labModel, pairing: pairingModel)
            }
            .defaultLaunchBehavior(.suppressed)
        #endif
    }
}
