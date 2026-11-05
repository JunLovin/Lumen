#if os(macOS)
    import SwiftUI

    struct ShelfView: View {
        let model: ShelfModel

        var body: some View {
            Group {
                if model.isHovering {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(model.items.reversed()) { item in
                                ShelfItemView(item: item, model: model)
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    ZStack {
                        ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                            ShelfItemView(item: item, model: model)
                                .rotationEffect(.degrees(
                                    Double(model.items.count - 1 - index) * DesignTokens.Shelf.fanDegrees
                                ))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: model.isHovering)
            .onHover { model.isHovering = $0 }
        }
    }

    private struct ShelfItemView: View {
        let item: ShelfItem
        let model: ShelfModel

        var body: some View {
            Image(nsImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: DesignTokens.Shelf.itemPoints, height: DesignTokens.Shelf.itemPoints)
                .clipShape(.rect(cornerRadius: 10))
                .overlay { outline }
                .overlay(alignment: .topTrailing) { removeButton }
                .shadow(radius: 8)
                .opacity(item.hasFailed ? 0.4 : 1)
                .contentShape(.rect)
                .onTapGesture { model.onSave(item.id) }
                .onDrag { item.fileURL.flatMap(NSItemProvider.init(contentsOf:)) ?? NSItemProvider() }
                .help(item.savedName.map { String(localized: "shelf.saved \($0)", bundle: .module) } ?? "")
        }

        @ViewBuilder private var removeButton: some View {
            if model.isHovering {
                Button { model.onRemove(item.id) } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }

        @ViewBuilder private var outline: some View {
            if item.hasFailed {
                Image(systemName: "exclamationmark.triangle.fill").font(.title).foregroundStyle(.white)
            } else if item.fileURL == nil {
                RoundedRectangle(cornerRadius: 10)
                    .trim(from: 0, to: item.progress)
                    .stroke(.white, lineWidth: 3)
                    .animation(.linear(duration: 0.2), value: item.progress)
            } else if item.savedName != nil {
                Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.white, .green)
            }
        }
    }
#endif
