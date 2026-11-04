import LumenDomain
import Testing

private func image(_ colors: [(UInt8, UInt8, UInt8, Int)]) -> [UInt8] {
    colors.flatMap { red, green, blue, count in
        (0 ..< count).flatMap { _ in [red, green, blue] }
    }
}

@Test func aVividColorLeadsOverALargerDullArea() throws {
    let palette = try #require(GlowPalette.dominant(inRGB: image([(120, 120, 120, 80), (230, 30, 30, 20)])))
    #expect(palette.primary.red > palette.primary.blue * 2)
}

@Test func aDarkPhotoStillProducesVisibleLight() throws {
    let palette = try #require(GlowPalette.dominant(inRGB: image([(20, 5, 5, 50)])))
    #expect(palette.primary.red >= 0.74)
}

@Test func aBlackPhotoFallsBackToNeutralLight() throws {
    let palette = try #require(GlowPalette.dominant(inRGB: image([(0, 0, 0, 10)])))
    #expect(palette.primary.green >= 0.74)
}

@Test func noPixelsMeansNoPalette() {
    #expect(GlowPalette.dominant(inRGB: []) == nil)
}

@Test func theFlatFormRoundTrips() throws {
    let flat: [Float] = [1, 0.5, 0, 0, 0.5, 1, 1, 1, 0.5]
    #expect(try #require(GlowPalette(flat: flat)).flat == flat)
    #expect(GlowPalette(flat: [1, 2]) == nil)
}
