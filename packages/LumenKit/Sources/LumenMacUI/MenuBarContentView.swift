#if os(macOS)
    import AppKit
    import LumenApplication
    import SwiftUI

    public enum LabWindow {
        public static let identifier = "lab"
    }

    public struct MenuBarContentView: View {
        @Environment(\.openWindow) private var openWindow
        private let readProtocolVersion: ReadProtocolVersion
        private let pairing: PairingModel
        private let destination: DestinationFolder

        public init(readProtocolVersion: ReadProtocolVersion, pairing: PairingModel, destination: DestinationFolder) {
            self.destination = destination
            self.readProtocolVersion = readProtocolVersion
            self.pairing = pairing
        }

        @ViewBuilder private var pairingStatus: some View {
            if let name = pairing.pairedDeviceName {
                Text("menu.pairedWith \(name)", bundle: .module)
                Button { pairing.forget() } label: { Text("menu.forget", bundle: .module) }
            } else {
                Text("menu.bringCloser", bundle: .module)
            }
        }

        public var body: some View {
            Text("menu.title", bundle: .module)
            Text("menu.protocolVersion \(readProtocolVersion().rawValue)", bundle: .module)
            pairingStatus
            Divider()
            Button { destination.choose() } label: { Text("menu.chooseFolder", bundle: .module) }
            if destination.folderName != nil {
                Button { destination.clear() } label: { Text("menu.useShelf", bundle: .module) }
            }
            #if DEBUG
                Button {
                    openWindow(id: LabWindow.identifier)
                    NSApplication.shared.activate()
                } label: {
                    Text("menu.openLab", bundle: .module)
                }
            #endif
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("menu.quit", bundle: .module)
            }
            .keyboardShortcut("q")
        }
    }
#endif
