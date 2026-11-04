import AppKit

// Run with: swift scripts/render-icons.swift
// Draws the app icons from code, so there is no binary source file to keep in sync.

private let primary = NSColor(red: 0.42, green: 0.62, blue: 1.0, alpha: 1)
private let secondary = NSColor(red: 0.78, green: 0.45, blue: 1.0, alpha: 1)
private let highlight = NSColor(red: 1.0, green: 0.86, blue: 0.72, alpha: 1)

private func gradient(_ colors: [NSColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: colors.map(\.cgColor) as CFArray,
        locations: locations
    )!
}

private func drawArtwork(in context: CGContext, side: CGFloat) {
    let background = gradient(
        [NSColor(red: 0.07, green: 0.07, blue: 0.13, alpha: 1), NSColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1)],
        [0, 1]
    )
    context.drawLinearGradient(background, start: CGPoint(x: 0, y: side), end: CGPoint(x: side, y: 0), options: [])

    let seamX = side * 0.68
    context.saveGState()
    context.setBlendMode(.plusLighter)
    let glow = gradient(
        [
            secondary.withAlphaComponent(0),
            primary.withAlphaComponent(0.55),
            highlight,
            primary.withAlphaComponent(0.55),
            secondary.withAlphaComponent(0),
        ],
        [0, 0.42, 0.5, 0.58, 1]
    )
    context.drawLinearGradient(
        glow,
        start: CGPoint(x: seamX - side * 0.26, y: 0),
        end: CGPoint(x: seamX + side * 0.26, y: 0),
        options: []
    )
    context.restoreGState()

    let card = CGRect(x: side * 0.2, y: side * 0.31, width: side * 0.38, height: side * 0.38)
    context.saveGState()
    context.translateBy(x: card.midX, y: card.midY)
    context.rotate(by: -0.14)
    context.translateBy(x: -card.midX, y: -card.midY)
    context.setShadow(offset: CGSize(width: 0, height: -side * 0.015), blur: side * 0.05, color: NSColor.black.cgColor)
    let path = CGPath(roundedRect: card, cornerWidth: side * 0.05, cornerHeight: side * 0.05, transform: nil)
    context.addPath(path)
    context.setFillColor(NSColor.white.cgColor)
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0)
    context.addPath(path)
    context.clip()
    let photo = gradient([highlight, secondary, primary], [0, 0.55, 1])
    context.drawLinearGradient(
        photo,
        start: CGPoint(x: card.minX, y: card.maxY),
        end: CGPoint(x: card.maxX, y: card.minY),
        options: []
    )
    context.restoreGState()

    context.setBlendMode(.plusLighter)
    for index in 0 ..< 46 {
        let progress = CGFloat(index) / 46
        let x = card.maxX - side * 0.02 + progress * (seamX - card.maxX + side * 0.12)
        let scatter = abs(sin(CGFloat(index) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
        let y = side * (0.34 + 0.32 * scatter)
        let radius = side * (0.012 - 0.008 * progress)
        context.setFillColor(highlight.withAlphaComponent(0.95 - 0.5 * progress).cgColor)
        context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }
}

private func bitmap(pixels: Int, hasAlpha: Bool, draw: (CGContext) -> Void) -> Data {
    let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (hasAlpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue
    )!
    draw(context)
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

private func write(_ data: Data, to path: String) {
    try! FileManager.default.createDirectory(
        at: URL(filePath: path).deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try! data.write(to: URL(filePath: path))
}

private let iosSet = "apps/ios/ios/Lumen/Images.xcassets/AppIcon.appiconset"
write(bitmap(pixels: 1024, hasAlpha: false) { drawArtwork(in: $0, side: 1024) }, to: "\(iosSet)/AppIcon.png")
write(Data("""
{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

""".utf8), to: "\(iosSet)/Contents.json")

private let macSet = "apps/macos/Lumen/Assets.xcassets/AppIcon.appiconset"
private var entries: [String] = []
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (
    512,
    2
)] {
    let pixels = points * scale
    let side = CGFloat(pixels)
    let name = "icon_\(points)x\(points)@\(scale)x.png"
    write(bitmap(pixels: pixels, hasAlpha: true) { context in
        let inset = side * 0.1
        let tile = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
        context.addPath(CGPath(
            roundedRect: tile,
            cornerWidth: tile.width * 0.225,
            cornerHeight: tile.width * 0.225,
            transform: nil
        ))
        context.clip()
        context.translateBy(x: inset, y: inset)
        drawArtwork(in: context, side: tile.width)
    }, to: "\(macSet)/\(name)")
    entries
        .append(
            #"    { "filename" : "\#(name)", "idiom" : "mac", "scale" : "\#(scale)x", "size" : "\#(points)x\#(points)" }"#
        )
}

write(Data("""
{
  "images" : [
\(entries.joined(separator: ",\n"))
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

""".utf8), to: "\(macSet)/Contents.json")
write(
    Data(#"{ "info" : { "author" : "xcode", "version" : 1 } }"#.utf8 + [10]),
    to: "apps/macos/Lumen/Assets.xcassets/Contents.json"
)
