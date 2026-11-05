import UIKit
import UniformTypeIdentifiers

@MainActor
final class FilePicker: NSObject, UIDocumentPickerDelegate {
    private let onPick: ([URL]) -> Void

    init(onPick: @escaping ([URL]) -> Void) {
        self.onPick = onPick
    }

    func present() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard var root = scene?.keyWindow?.rootViewController else { return }
        while let presented = root.presentedViewController {
            root = presented
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item, .folder])
        picker.allowsMultipleSelection = true
        picker.delegate = self
        root.present(picker, animated: true)
    }

    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick(urls)
    }
}
