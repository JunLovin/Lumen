public enum CorrelationCurve {
    public static func downsample(_ envelope: [Float], pointCount: Int) -> [Float] {
        guard pointCount > 0, envelope.count > pointCount else { return envelope }
        let bucket = envelope.count / pointCount
        return (0 ..< pointCount).map { point in
            envelope[point * bucket ..< (point + 1) * bucket].max() ?? 0
        }
    }
}
