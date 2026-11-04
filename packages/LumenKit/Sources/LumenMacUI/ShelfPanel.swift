#if os(macOS)
    import AppKit
    import LumenDomain
    import Observation
    import SwiftUI

    struct ShelfItem: Identifiable {
        let id: UInt32
        let image: NSImage
        var progress: Double = 0
        var fileURL: URL?
        var hasFailed = false
        var savedName: String?
    }

    @MainActor
    @Observable
    final class ShelfModel {
        var items: [ShelfItem] = []
        var isHovering = false
        var onSave: (UInt32) -> Void = { _ in }
        var onRemove: (UInt32) -> Void = { _ in }
    }

    private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
        /// The shelf never becomes key, and AppKit would otherwise swallow the first click on it.
        override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
            true
        }
    }

    @MainActor
    final class ShelfPanel {
        private let model = ShelfModel()
        private let destination: DestinationFolder
        private var panel: NSPanel?
        private var hideTask: Task<Void, Never>?
        private var earlyStages: [UInt32: TransferStage] = [:]

        init(destination: DestinationFolder) {
            self.destination = destination
            model.onSave = { [weak self] id in self?.save(id) }
            model.onRemove = { [weak self] id in self?.remove(id) }
        }

        private func save(_ id: UInt32) {
            guard
                let index = model.items.firstIndex(where: { $0.id == id }),
                let file = model.items[index].fileURL
            else { return }
            model.items[index].savedName = destination.save(file)?.lastPathComponent
        }

        private func remove(_ id: UInt32) {
            model.items.removeAll { $0.id == id }
            if model.items.isEmpty {
                panel?.orderOut(nil)
            }
        }

        func slot(forEdge edge: PhoneEdge, in space: MacSpace, objectSize _: Double) -> MacPoint {
            let offset = DesignTokens.Shelf.insetPoints + DesignTokens.Shelf.widthPoints / 2
            return MacPoint(x: edge == .right ? offset : space.widthPoints - offset, y: space.heightPoints / 2)
        }

        func add(jpeg: [UInt8], edge: PhoneEdge, session: UInt32) {
            guard let image = NSImage(data: Data(jpeg)) else { return }
            model.items.append(ShelfItem(id: session, image: image))
            if let stage = earlyStages.removeValue(forKey: session) {
                apply(stage, to: session)
            }
            show(edge: edge)
        }

        func update(_ update: TransferUpdate) {
            let id = update.transferID
            if model.items.contains(where: { $0.id == id }) {
                apply(update.stage, to: id)
            } else if case .cancelled = update.stage {
                earlyStages[id] = nil
            } else {
                earlyStages[id] = update.stage
            }
        }

        private func apply(_ stage: TransferStage, to id: UInt32) {
            guard let index = model.items.firstIndex(where: { $0.id == id }) else { return }
            switch stage {
            case let .preparing(fraction):
                model.items[index].progress = fraction * 0.1
            case let .receiving(received, total):
                model.items[index].progress = total > 0 ? 0.1 + 0.9 * Double(received) / Double(total) : 0.1
            case let .completed(path, _):
                model.items[index].fileURL = destination.deliver(URL(filePath: path))
                model.items[index].progress = 1
            case .failed, .cancelled:
                model.items[index].hasFailed = true
            }
        }

        private func show(edge: PhoneEdge) {
            let panel = panel ?? makePanel()
            self.panel = panel
            let screen = BuiltInScreen.current.frame
            let width = DesignTokens.Shelf.widthPoints
            let height = DesignTokens.Shelf.heightPoints
            let inset = DesignTokens.Shelf.insetPoints
            panel.setFrame(
                NSRect(
                    x: edge == .right ? screen.minX + inset : screen.maxX - inset - width,
                    y: screen.midY - height / 2,
                    width: width,
                    height: height
                ),
                display: true
            )
            panel.orderFrontRegardless()
            scheduleHide()
        }

        private func scheduleHide() {
            hideTask?.cancel()
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(DesignTokens.Shelf.hideSeconds))
                guard let self, !Task.isCancelled else { return }
                let isBusy = model.isHovering || model.items.contains { $0.fileURL == nil && !$0.hasFailed }
                if isBusy {
                    scheduleHide()
                } else {
                    panel?.orderOut(nil)
                }
            }
        }

        private func makePanel() -> NSPanel {
            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = FirstClickHostingView(rootView: ShelfView(model: model))
            return panel
        }
    }
#endif
