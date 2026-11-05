import LumenApplication
import LumenMacUI
import LumenTransport
import SwiftUI

@main
struct LumenApp: App {
    private let readProtocolVersion = ReadProtocolVersion(protocolInfo: ProtocolInfoAdapter())

    var body: some Scene {
        MenuBarExtra("Lumen", systemImage: "sparkles") {
            MenuBarContentView(readProtocolVersion: readProtocolVersion)
        }
    }
}
