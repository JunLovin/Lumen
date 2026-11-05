#if os(macOS)
    import AppKit
    import CoreGraphics
    import IOSurface
    import ScreenCaptureKit

    private final class LatestFrame: NSObject, SCStreamOutput, @unchecked Sendable {
        private let lock = NSLock()
        private var surface: IOSurfaceRef?

        var latest: IOSurfaceRef? {
            lock.withLock { surface }
        }

        func clear() {
            lock.withLock { surface = nil }
        }

        func stream(_: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
            guard
                type == .screen,
                let image = CMSampleBufferGetImageBuffer(buffer),
                let next = CVPixelBufferGetIOSurface(image)?.takeUnretainedValue()
            else { return }
            lock.withLock { surface = next }
        }
    }

    @MainActor
    final class LensCapture {
        private static let framesPerSecond: Int32 = 60
        private static let queueDepth = 3
        private let frame = LatestFrame()
        private var stream: SCStream?
        private var startTask: Task<Void, Never>?

        var latestSurface: IOSurfaceRef? {
            frame.latest
        }

        func start() {
            guard stream == nil, startTask == nil, CGPreflightScreenCaptureAccess() else { return }
            startTask = Task { [weak self] in
                await self?.open()
                self?.startTask = nil
            }
        }

        func stop() {
            startTask?.cancel()
            let running = stream
            stream = nil
            frame.clear()
            Task { try? await running?.stopCapture() }
        }

        private func open() async {
            let screen = BuiltInScreen.current
            guard
                let identifier = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID,
                let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
                let display = content.displays.first(where: { $0.displayID == identifier }),
                !Task.isCancelled
            else { return }
            let lumen = content.applications.filter { $0.processID == getpid() }
            let filter = SCContentFilter(display: display, excludingApplications: lumen, exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = Int(screen.frame.width * screen.backingScaleFactor)
            configuration.height = Int(screen.frame.height * screen.backingScaleFactor)
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.showsCursor = false
            configuration.queueDepth = Self.queueDepth
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: Self.framesPerSecond)
            let opened = SCStream(filter: filter, configuration: configuration, delegate: nil)
            guard
                (
                    try? opened.addStreamOutput(frame, type: .screen, sampleHandlerQueue: .global(
                        qos: .userInteractive
                    ))
                ) !=
                nil,
                await (try? opened.startCapture()) != nil
            else { return }
            stream = opened
        }
    }
#endif
