import LumenApplication
import LumenMacUI
import LumenTransport
import SwiftUI

@main
struct LumenApp: App {
    private let readProtocolVersion = ReadProtocolVersion(protocolInfo: ProtocolInfoAdapter())
    @State private var labModel: LabModel

    init() {
        let link = MacPeerLink()
        let clock = SystemClockAdapter()
        let amplitude = DesignTokens.Chirp.defaultAmplitude
        let session = PeerLabSession(
            link: link,
            clock: clock,
            chirpPlayer: ChirpPlayerAdapter(),
            chirpAmplitude: amplitude
        )
        let model = LabModel(session: session, clock: clock, chirpAmplitude: amplitude)
        _labModel = State(initialValue: model)
        Task { await model.setListening(link.start()) }
        Task { await session.run() }
        Task { await model.consumeUpdates() }
    }

    var body: some Scene {
        MenuBarExtra("Lumen", systemImage: "sparkles") {
            MenuBarContentView(readProtocolVersion: readProtocolVersion)
        }
        #if DEBUG
            Window("Lumen Lab", id: LabWindow.identifier) {
                LabView(model: labModel)
            }
            .defaultLaunchBehavior(.suppressed)
        #endif
    }
}
