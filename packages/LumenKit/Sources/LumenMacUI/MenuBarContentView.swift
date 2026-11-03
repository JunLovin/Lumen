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

        public init(readProtocolVersion: ReadProtocolVersion) {
            self.readProtocolVersion = readProtocolVersion
        }

        public var body: some View {
            Text("menu.title", bundle: .module)
            Text("menu.protocolVersion \(readProtocolVersion().rawValue)", bundle: .module)
            Divider()
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
