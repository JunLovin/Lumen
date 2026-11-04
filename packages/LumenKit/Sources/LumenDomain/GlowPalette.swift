public struct PaletteColor: Sendable, Equatable {
    public let red: Float
    public let green: Float
    public let blue: Float

    public init(red: Float, green: Float, blue: Float) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    var brightness: Float {
        max(red, green, blue)
    }

    var saturation: Float {
        brightness > 0 ? (brightness - min(red, green, blue)) / brightness : 0
    }

    func distanceSquared(to other: PaletteColor) -> Float {
        let (dr, dg, db) = (red - other.red, green - other.green, blue - other.blue)
        return dr * dr + dg * dg + db * db
    }

    /// A dark photo still has to read as light on a screen edge.
    func lifted(toBrightness minimum: Float) -> PaletteColor {
        guard brightness > 0, brightness < minimum else {
            return brightness > 0 ? self : PaletteColor(red: minimum, green: minimum, blue: minimum)
        }
        let scale = minimum / brightness
        return PaletteColor(red: red * scale, green: green * scale, blue: blue * scale)
    }
}

public struct GlowPalette: Sendable, Equatable {
    private static let clusterCount = 5
    private static let iterations = 8
    private static let minimumBrightness: Float = 0.75
    private static let channelsPerColor = 3

    public let primary: PaletteColor
    public let secondary: PaletteColor
    public let highlight: PaletteColor

    public init(primary: PaletteColor, secondary: PaletteColor, highlight: PaletteColor) {
        self.primary = primary
        self.secondary = secondary
        self.highlight = highlight
    }

    public init?(flat: [Float]) {
        guard flat.count == Self.channelsPerColor * 3 else { return nil }
        primary = PaletteColor(red: flat[0], green: flat[1], blue: flat[2])
        secondary = PaletteColor(red: flat[3], green: flat[4], blue: flat[5])
        highlight = PaletteColor(red: flat[6], green: flat[7], blue: flat[8])
    }

    public var flat: [Float] {
        [primary, secondary, highlight].flatMap { [$0.red, $0.green, $0.blue] }
    }

    /// `rgb` holds three bytes per pixel.
    public static func dominant(inRGB rgb: [UInt8]) -> GlowPalette? {
        let pixels = stride(from: 0, to: rgb.count - channelsPerColor + 1, by: channelsPerColor).map {
            PaletteColor(red: Float(rgb[$0]) / 255, green: Float(rgb[$0 + 1]) / 255, blue: Float(rgb[$0 + 2]) / 255)
        }
        guard !pixels.isEmpty else { return nil }
        let clusters = kMeans(pixels)
        let ranked = clusters.sorted { score($0) > score($1) }
        let primary = ranked[0].center
        let secondary = ranked.dropFirst().max { lhs, rhs in
            lhs.center.distanceSquared(to: primary) * score(lhs) < rhs.center.distanceSquared(to: primary) * score(rhs)
        }?.center ?? primary
        let highlight = clusters.max { $0.center.brightness < $1.center.brightness }?.center ?? primary
        return GlowPalette(
            primary: primary.lifted(toBrightness: minimumBrightness),
            secondary: secondary.lifted(toBrightness: minimumBrightness),
            highlight: highlight.lifted(toBrightness: minimumBrightness)
        )
    }

    private struct Cluster {
        var center: PaletteColor
        var count = 0
    }

    /// Vivid colors win over large dull areas, so a sky behind a red coat still glows red.
    private static func score(_ cluster: Cluster) -> Float {
        Float(cluster.count) * (0.1 + cluster.center.saturation)
    }

    private static func kMeans(_ pixels: [PaletteColor]) -> [Cluster] {
        let seeds = (0 ..< min(clusterCount, pixels.count)).map { pixels[$0 * pixels.count / clusterCount] }
        var clusters = seeds.map { Cluster(center: $0) }
        for _ in 0 ..< iterations {
            var sums = [(red: Float, green: Float, blue: Float, count: Int)](
                repeating: (0, 0, 0, 0),
                count: clusters.count
            )
            for pixel in pixels {
                let nearest = clusters.indices.min {
                    clusters[$0].center.distanceSquared(to: pixel) < clusters[$1].center.distanceSquared(to: pixel)
                } ?? 0
                sums[nearest].red += pixel.red
                sums[nearest].green += pixel.green
                sums[nearest].blue += pixel.blue
                sums[nearest].count += 1
            }
            for index in clusters.indices where sums[index].count > 0 {
                let count = Float(sums[index].count)
                clusters[index] = Cluster(
                    center: PaletteColor(
                        red: sums[index].red / count,
                        green: sums[index].green / count,
                        blue: sums[index].blue / count
                    ),
                    count: sums[index].count
                )
            }
        }
        return clusters
    }
}
