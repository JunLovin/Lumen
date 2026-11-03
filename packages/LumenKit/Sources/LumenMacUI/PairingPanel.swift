#if os(macOS)
    import AppKit
    import SwiftUI

    @MainActor
    final class PairingPanel {
        private static let size = NSSize(width: 360, height: 420)
        private let panel: NSPanel

        init(model: PairingModel) {
            panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: Self.size),
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: PairingView(model: model))
            panel.center()
        }

        func show() {
            panel.orderFrontRegardless()
        }

        func hide() {
            panel.orderOut(nil)
        }
    }
#endif
