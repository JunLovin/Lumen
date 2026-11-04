#if os(macOS)
    import AppKit
    import LumenDomain

    @MainActor
    final class FinderDragMonitor {
        private static let activationDistancePoints = 320.0
        var placement: PlacementSide = .unknown
        private let onDrop: ([String]) -> Void
        private var monitor: Any?
        private var baselineChangeCount = NSPasteboard(name: .drag).changeCount
        private var leftZone: DropZonePanel?
        private var rightZone: DropZonePanel?

        init(onDrop: @escaping ([String]) -> Void) {
            self.onDrop = onDrop
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [
                .leftMouseDown,
                .leftMouseDragged,
                .leftMouseUp,
            ]) { [weak self] event in
                let type = event.type
                MainActor.assumeIsolated { self?.handle(type) }
            }
        }

        private func handle(_ type: NSEvent.EventType) {
            switch type {
            case .leftMouseDown:
                baselineChangeCount = NSPasteboard(name: .drag).changeCount
            case .leftMouseDragged:
                updateZones()
            default:
                deactivate()
            }
        }

        private func updateZones() {
            let pasteboard = NSPasteboard(name: .drag)
            guard
                pasteboard.changeCount != baselineChangeCount,
                pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            else { return }
            let screen = BuiltInScreen.current.frame
            let mouse = NSEvent.mouseLocation
            let nearLeft = mouse.x - screen.minX < Self.activationDistancePoints
            let nearRight = screen.maxX - mouse.x < Self.activationDistancePoints
            if nearLeft, placement != .right {
                zone(onLeft: true).activate()
            }
            if nearRight, placement != .left {
                zone(onLeft: false).activate()
            }
        }

        private func zone(onLeft: Bool) -> DropZonePanel {
            if onLeft, let leftZone {
                return leftZone
            }
            if !onLeft, let rightZone {
                return rightZone
            }
            let zone = DropZonePanel(onLeft: onLeft) { [weak self] paths in
                self?.onDrop(paths)
                self?.deactivate()
            }
            if onLeft {
                leftZone = zone
            } else {
                rightZone = zone
            }
            return zone
        }

        private func deactivate() {
            leftZone?.deactivate()
            rightZone?.deactivate()
        }
    }

    @MainActor
    private final class DropZonePanel {
        private let panel: NSPanel
        private let glow: EdgeOverlayPanel?

        init(onLeft: Bool, onDrop: @escaping ([String]) -> Void) {
            let screen = BuiltInScreen.current.frame
            let width = DesignTokens.Glow.overlayWidthPoints
            let frame = NSRect(
                x: onLeft ? screen.minX : screen.maxX - width,
                y: screen.minY,
                width: width,
                height: screen.height
            )
            panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.contentView = DropTargetView(onDrop: onDrop)
            glow = EdgeOverlayPanel(onLeftEdge: onLeft) { _ in }
        }

        func activate() {
            guard !panel.isVisible else { return }
            glow?.show()
            glow?.setProximity(1)
            panel.orderFrontRegardless()
        }

        func deactivate() {
            glow?.setProximity(0)
            glow?.hide()
            panel.orderOut(nil)
        }
    }

    private final class DropTargetView: NSView {
        private let onDrop: ([String]) -> Void

        init(onDrop: @escaping ([String]) -> Void) {
            self.onDrop = onDrop
            super.init(frame: .zero)
            registerForDraggedTypes([.fileURL])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override func draggingEntered(_: any NSDraggingInfo) -> NSDragOperation {
            .copy
        }

        override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
            let urls = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL]
            guard let urls, !urls.isEmpty else { return false }
            onDrop(urls.map(\.path))
            return true
        }
    }
#endif
