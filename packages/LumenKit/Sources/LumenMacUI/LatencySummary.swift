#if os(macOS)
    import LumenDomain

    public struct LatencySummary: Equatable {
        public let p50: Double
        public let p95: Double
        public let max: Double
        public let count: Int

        init?(window: SampleWindow) {
            guard let p50 = window.percentile(0.5), let p95 = window.percentile(0.95) else { return nil }
            self.p50 = p50
            self.p95 = p95
            max = window.percentile(1) ?? p95
            count = window.count
        }
    }
#endif
