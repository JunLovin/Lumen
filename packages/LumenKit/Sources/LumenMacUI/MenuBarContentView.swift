#if os(macOS)
    import AppKit
    import LumenApplication
    import SwiftUI

    public struct MenuBarContentView: View {
        private let readProtocolVersion: ReadProtocolVersion

        public init(readProtocolVersion: ReadProtocolVersion) {
            self.readProtocolVersion = readProtocolVersion
        }

        public var body: some View {
            Text("menu.title", bundle: .module)
            Text("menu.protocolVersion \(readProtocolVersion().rawValue)", bundle: .module)
            Divider()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("menu.quit", bundle: .module)
            }
            .keyboardShortcut("q")
        }
    }
#endif
