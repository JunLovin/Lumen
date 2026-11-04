import UIKit

final class Haptics: Sendable {
    func impact(style: Int) {
        Task { @MainActor in
            let styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.soft, .medium, .light, .rigid]
            let feedbackStyle = styles.indices.contains(style) ? styles[style] : .soft
            UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        }
    }
}
