#if os(macOS)
    public extension LabModel {
        func toggleOverlay() {
            if isOverlayVisible {
                overlay?.hide()
                isOverlayVisible = false
                return
            }
            if overlay == nil {
                overlay = EdgeOverlayPanel { [weak self] milliseconds in
                    Task { @MainActor in self?.recordGPUTime(milliseconds) }
                }
            }
            overlay?.show()
            isOverlayVisible = overlay != nil
            pushProximity()
        }

        internal func recordGPUTime(_ milliseconds: Double) {
            gpuWindow.add(milliseconds)
            let now = clock.nowNanoseconds()
            if now - lastPublishNs > Self.statsPublishIntervalNs {
                publishStats(at: now)
            }
        }
    }
#endif
