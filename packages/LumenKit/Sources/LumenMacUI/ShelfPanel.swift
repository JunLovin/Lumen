#if os(macOS)
    import AppKit
    import LumenDomain
    import Observation
    import SwiftUI

    struct ShelfItem: Identifiable {
        let id: UInt32
        let image: NSImage
        let fileURL: URL
    }

    @MainActor
    @Observable
    final class ShelfModel {
        var items: [ShelfItem] = []
        var isHovering = false
    }

    @MainActor
    final class ShelfPanel {
        private let model = ShelfModel()
        private var panel: NSPanel?
        private var hideTask: Task<Void, Never>?

        func slot(forEdge edge: PhoneEdge, in space: MacSpace, objectSize _: Double) -> MacPoint {
            let offset = DesignTokens.Shelf.insetPoints + DesignTokens.Shelf.widthPoints / 2
            return MacPoint(x: edge == .right ? offset : space.widthPoints - offset, y: space.heightPoints / 2)
        }

        func add(jpeg: [UInt8], edge: PhoneEdge, session: UInt32) {
            let data = Data(jpeg)
            guard let image = NSImage(data: data), let url = Self.write(data, session: session) else { return }
            model.items.append(ShelfItem(id: session, image: image, fileURL: url))
            show(edge: edge)
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
                if model.isHovering {
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
            panel.contentView = NSHostingView(rootView: ShelfView(model: model))
            return panel
        }

        private static func write(_ data: Data, session: UInt32) -> URL? {
            let url = FileManager.default.temporaryDirectory
                .appending(path: "Lumen-\(session)-\(UUID().uuidString.prefix(8)).jpg")
            return (try? data.write(to: url)) == nil ? nil : url
        }
    }

    private struct ShelfView: View {
        let model: ShelfModel

        var body: some View {
            ZStack {
                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                    let fromTop = model.items.count - 1 - index
                    Image(nsImage: item.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: DesignTokens.Shelf.itemPoints, height: DesignTokens.Shelf.itemPoints)
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(radius: 8)
                        .rotationEffect(.degrees(model.isHovering ? Double(fromTop) * DesignTokens.Shelf
                                .fanDegrees : 0))
                        .offset(y: model.isHovering ? Double(fromTop) * -14 : 0)
                        .onDrag { NSItemProvider(contentsOf: item.fileURL) ?? NSItemProvider() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: model.isHovering)
            .onHover { model.isHovering = $0 }
        }
    }
#endif
