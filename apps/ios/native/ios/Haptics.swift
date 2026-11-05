import UIKit

final class Haptics: Sendable {
    func impact(style: Int) {
        Task { @MainActor in
            let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = style == 0 ? .soft : .medium
            UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        }
    }
}
