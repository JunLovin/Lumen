import Foundation

enum SharedOutbox {
    static let appGroup = "group.com.junlovin.lumen"

    static func flush(using sender: TransferSender) async {
        let manager = FileManager.default
        guard
            let outbox = manager.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
                .appending(path: "Outbox"),
            let batches = try? manager.contentsOfDirectory(at: outbox, includingPropertiesForKeys: nil)
        else { return }
        for batch in batches {
            let files = (try? manager.contentsOfDirectory(at: batch, includingPropertiesForKeys: nil)) ?? []
            await sender.sendDirect(files: files)
            try? manager.removeItem(at: batch)
        }
    }
}
