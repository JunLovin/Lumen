#if os(macOS)
    import AppKit
    import LumenDomain

    @MainActor
    enum BuiltInScreen {
        /// Fallback for displays that report no physical size: a typical laptop's 127 points per inch.
        private static let fallbackPointsPerMillimeter = 5.0

        static var current: NSScreen {
            NSScreen.screens.first { displayID(of: $0).map { CGDisplayIsBuiltin($0) != 0 } ?? false }
                ?? NSScreen.main
                ?? NSScreen.screens[0]
        }

        static var space: MacSpace {
            let screen = current
            let millimeters = displayID(of: screen).map { CGDisplayScreenSize($0).width } ?? 0
            return MacSpace(
                widthPoints: screen.frame.width,
                heightPoints: screen.frame.height,
                pointsPerMillimeter: millimeters > 0 ? screen.frame.width / millimeters : fallbackPointsPerMillimeter,
                entryStripFraction: DesignTokens.Mirror.entryStripFraction
            )
        }

        private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
            screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        }
    }
#endif
