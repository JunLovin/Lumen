#if os(macOS)
    import AppKit
    import SwiftUI

    @MainActor
    public enum OnboardingPanel {
        private static let seenKey = "onboarding.seen"
        private static var window: NSWindow?

        public static func showIfNeeded() {
            guard !UserDefaults.standard.bool(forKey: seenKey) else { return }
            let content = OnboardingView {
                UserDefaults.standard.set(true, forKey: seenKey)
                window?.close()
                window = nil
            }
            let onboarding = NSWindow(contentViewController: NSHostingController(rootView: content))
            onboarding.styleMask = [.titled, .fullSizeContentView]
            onboarding.titlebarAppearsTransparent = true
            onboarding.isReleasedWhenClosed = false
            onboarding.center()
            window = onboarding
            NSApplication.shared.activate()
            onboarding.makeKeyAndOrderFront(nil)
        }
    }

    private struct OnboardingView: View {
        let onDone: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("onboarding.title", bundle: .module).font(.title2.bold())
                Label { Text("onboarding.pair", bundle: .module) } icon: {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                }
                Label { Text("onboarding.toMac", bundle: .module) } icon: { Image(systemName: "photo.on.rectangle") }
                Label { Text("onboarding.toPhone", bundle: .module) } icon: { Image(systemName: "doc.on.doc") }
                HStack {
                    Spacer()
                    Button(action: onDone) { Text("onboarding.done", bundle: .module) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 420)
        }
    }
#endif
