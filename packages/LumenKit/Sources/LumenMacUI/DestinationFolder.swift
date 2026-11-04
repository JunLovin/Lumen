#if os(macOS)
    import AppKit
    import Observation

    @MainActor
    @Observable
    public final class DestinationFolder {
        private static let bookmarkKey = "lumen.destination.bookmark"
        public private(set) var folderName: String?
        @ObservationIgnored private var folder: URL?

        public init() {
            guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
            var isStale = false
            folder = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            folderName = folder?.lastPathComponent
        }

        public func choose() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            NSApplication.shared.activate()
            guard panel.runModal() == .OK, let url = panel.url,
                  let data = try? url.bookmarkData(options: .withSecurityScope) else { return }
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
            folder = url
            folderName = url.lastPathComponent
        }

        public func clear() {
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
            folder = nil
            folderName = nil
        }

        func deliver(_ source: URL) -> URL {
            guard let folder else { return source }
            return copy(source, into: folder) ?? source
        }

        func save(_ source: URL) -> URL? {
            if let folder, source.path.hasPrefix(folder.path) {
                return source
            }
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            return (folder ?? downloads).flatMap { copy(source, into: $0) }
        }

        private func copy(_ source: URL, into folder: URL) -> URL? {
            let didAccess = folder.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    folder.stopAccessingSecurityScopedResource()
                }
            }
            let target = availableURL(for: source.lastPathComponent, in: folder)
            return (try? FileManager.default.copyItem(at: source, to: target)) == nil ? nil : target
        }

        private func availableURL(for name: String, in folder: URL) -> URL {
            let original = folder.appending(path: name)
            guard FileManager.default.fileExists(atPath: original.path) else { return original }
            let base = original.deletingPathExtension().lastPathComponent
            let suffix = original.pathExtension
            var attempt = 2
            while true {
                let candidate = "\(base) \(attempt)" + (suffix.isEmpty ? "" : ".\(suffix)")
                let url = folder.appending(path: candidate)
                if !FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
                attempt += 1
            }
        }
    }
#endif
