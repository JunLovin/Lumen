import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private static let appGroup = "group.com.junlovin.lumen"
    private static let closeDelay = Duration.seconds(1.5)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = Self.message
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            await copySharedItems()
            try? await Task.sleep(for: Self.closeDelay)
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private static var message: String {
        Locale.current.language.languageCode?.identifier == "es"
            ? "Abre Lumen para enviarlo a tu Mac."
            : "Open Lumen to send this to your Mac."
    }

    private func copySharedItems() async {
        let manager = FileManager.default
        guard
            let outbox = manager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)?
            .appending(path: "Outbox/\(UUID().uuidString)"),
            (try? manager.createDirectory(at: outbox, withIntermediateDirectories: true)) != nil
        else { return }
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        for provider in items.flatMap({ $0.attachments ?? [] }) {
            await copy(provider, to: outbox)
        }
    }

    private func copy(_ provider: NSItemProvider, to outbox: URL) async {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) { url, _ in
                if let url {
                    try? FileManager.default.copyItem(at: url, to: outbox.appending(path: url.lastPathComponent))
                }
                continuation.resume()
            }
        }
    }
}
