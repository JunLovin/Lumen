// Draws the README preview, an illustration of the gesture rather than a screen recording.
// swiftc -O scripts/render-preview.swift -o /tmp/render-preview && /tmp/render-preview > /tmp/frames.rgb
// ffmpeg -f rawvideo -pix_fmt rgb24 -s 960x540 -r 24 -i /tmp/frames.rgb \
//   -vf "fps=20,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse" \
//   -loop 0 .github/assets/lumen-preview.gif

import AppKit
import CoreText

let W = 960, H = 540, FPS = 24, DURATION = 5.2
typealias C = SIMD3<Float>
func mix(_ a: C, _ b: C, _ t: Float) -> C {
    a + (b - a) * t
}

func clamp(_ x: Float, _ a: Float = 0, _ b: Float = 1) -> Float {
    min(max(x, a), b)
}

func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float {
    let t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t)
}

func fract(_ x: Float) -> Float {
    x - floor(x)
}

func hash(_ x: Float, _ y: Float) -> Float {
    fract(sin(x * 127.1 + y * 311.7) * 43758.5453)
}

func noise(_ x: Float, _ y: Float) -> Float {
    let cx = floor(x), cy = floor(y); let fx = x - cx, fy = y - cy
    let (ux, uy) = (fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy))
    let top = hash(cx, cy) + (hash(cx + 1, cy) - hash(cx, cy)) * ux
    let bottom = hash(cx, cy + 1) + (hash(cx + 1, cy + 1) - hash(cx, cy + 1)) * ux
    return top + (bottom - top) * uy
}

func fbm(_ x: Float, _ y: Float) -> Float {
    var (v, a, px, py): (Float, Float, Float, Float) = (0, 0.5, x, y)
    for _ in 0 ..< 4 {
        v += a * noise(px, py); px *= 2.02; py *= 2.02; a *= 0.5
    }
    return v
}

/// Sample photos are drawn from code: no real picture ships in the repository.
func photo(_ u: Float, _ v: Float, hue: Int) -> C {
    let palettes: [(C, C, C)] = [
        (C(0.98, 0.72, 0.30), C(0.86, 0.22, 0.42), C(0.20, 0.08, 0.28)),
        (C(0.45, 0.80, 0.95), C(0.15, 0.40, 0.75), C(0.05, 0.14, 0.25)),
        (C(0.70, 0.90, 0.60), C(0.20, 0.55, 0.40), C(0.05, 0.18, 0.15)),
        (C(0.95, 0.75, 0.85), C(0.55, 0.35, 0.80), C(0.15, 0.10, 0.30)),
        (C(0.95, 0.90, 0.70), C(0.75, 0.55, 0.35), C(0.25, 0.18, 0.15)),
    ]
    let (top, mid, low) = palettes[hue % palettes.count]
    var c = v < 0.6 ? mix(top, mid, v / 0.6) : mid
    let sunX = 0.3 + Float(hue % 4) * 0.13
    let d = hypot(u - sunX, v - 0.42)
    c = mix(c, C(1, 0.95, 0.75), smooth(0.17, 0.13, d))
    let ridge = 0.62 + 0.09 * sin(u * 7 + Float(hue)) + 0.05 * sin(u * 17 + Float(hue) * 2)
    if v > ridge {
        c = mix(low, low * 0.6, clamp((v - ridge) * 3))
    }
    return c
}

let phoneRect = (x: Float(72), y: Float(70), w: Float(196), h: Float(410), r: Float(26))
let macRect = (x: Float(360), y: Float(62), w: Float(560), h: Float(350), r: Float(10))
func rounded(_ px: Float, _ py: Float, _ q: (x: Float, y: Float, w: Float, h: Float, r: Float)) -> Float {
    let dx = abs(px - (q.x + q.w / 2)) - (q.w / 2 - q.r), dy = abs(py - (q.y + q.h / 2)) - (q.h / 2 - q.r)
    let dist = hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - q.r
    return clamp(0.5 - dist)
}

let cell: Float = 65, gridTop: Float = 128
func gridPixel(_ px: Float, _ py: Float) -> (C, Int)? {
    let col = Int((px - phoneRect.x) / (phoneRect.w / 3)), row = Int((py - gridTop) / cell)
    guard py >= gridTop, col >= 0, col < 3, row >= 0 else { return nil }
    let tileW = phoneRect.w / 3
    let u = (px - phoneRect.x - Float(col) * tileW) / tileW, v = (py - gridTop - Float(row) * cell) / cell
    guard u > 0.012, u < 0.988, v > 0.012, v < 0.988 else { return nil }
    return (photo(u, v, hue: col + row * 2 + row), col + row * 3)
}

let draggedIndex = 4
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(
    data: nil,
    width: W,
    height: H,
    bitsPerComponent: 8,
    bytesPerRow: W * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!
context.setFillColor(CGColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1)); context.fill(CGRect(
    x: 0,
    y: 0,
    width: W,
    height: H
))
func flip(_ y: Float, _ h: Float) -> CGFloat {
    CGFloat(Float(H) - y - h)
}

func box(_ q: (x: Float, y: Float, w: Float, h: Float, r: Float), grow: Float, _ color: CGColor) {
    context.setFillColor(color)
    let rect = CGRect(
        x: CGFloat(q.x - grow),
        y: flip(q.y - grow, q.h + 2 * grow),
        width: CGFloat(q.w + 2 * grow),
        height: CGFloat(q.h + 2 * grow)
    )
    context.addPath(CGPath(
        roundedRect: rect,
        cornerWidth: CGFloat(q.r + grow),
        cornerHeight: CGFloat(q.r + grow),
        transform: nil
    )); context.fillPath()
}

let frameGray = CGColor(red: 0.16, green: 0.16, blue: 0.19, alpha: 1)
box(phoneRect, grow: 7, frameGray); box(macRect, grow: 9, frameGray)
context.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.23, alpha: 1))
context.addPath(CGPath(
    roundedRect: CGRect(x: 324, y: CGFloat(H) - 438, width: 632, height: 11),
    cornerWidth: 5,
    cornerHeight: 5,
    transform: nil
)); context.fillPath()
func text(_ string: String, x: CGFloat, y: Float, size: CGFloat, gray: CGFloat, weight: NSFont.Weight = .regular) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(white: gray, alpha: 1),
    ]
    context.textPosition = CGPoint(x: x, y: CGFloat(Float(H) - y))
    CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes)), context)
}

text("Animated illustration of the gesture, not a screen recording", x: 324, y: 505, size: 13, gray: 0.55)
text("Lumen", x: 72, y: 505, size: 15, gray: 0.92, weight: .semibold)
text("Photos", x: 84, y: 118, size: 17, gray: 0.92, weight: .semibold)
let base = context.makeImage()!
let baseData = base.dataProvider!.data! as Data
var background = [C](repeating: .zero, count: W * H)
for i in 0 ..< W * H {
    background[i] = C(
        Float(baseData[i * 4]),
        Float(baseData[i * 4 + 1]),
        Float(baseData[i * 4 + 2])
    ) / 255
}

var phoneMask = [Float](repeating: 0, count: W * H), macMask = phoneMask, gridColor = background, tileIndex = [Int](
    repeating: -1,
    count: W * H
)
for y in 0 ..< H {
    for x in 0 ..< W {
        let i = y * W + x, (px, py) = (Float(x) + 0.5, Float(y) + 0.5)
        phoneMask[i] = rounded(px, py, phoneRect); macMask[i] = rounded(px, py, macRect)
        if phoneMask[i] > 0 {
            var c = C(0.02, 0.02, 0.03)
            if py < gridTop {
                c = C(0.07, 0.07, 0.09) + background[i] * (background[i].x > 0.3 ? 1 : 0)
            }
            if let (tile, index) = gridPixel(px, py) {
                c = tile; tileIndex[i] = index
            }
            background[i] = mix(background[i], c, phoneMask[i])
        }
        if macMask[i] > 0 {
            let u = (px - macRect.x) / macRect.w, v = (py - macRect.y) / macRect.h
            var c = mix(C(0.10, 0.13, 0.26), C(0.28, 0.13, 0.30), (u + v) / 2)
            c = mix(c, C(0.45, 0.25, 0.42), smooth(0.35, 0.9, fbm(u * 3 + 2, v * 3)) * 0.5)
            if v < 0.055 {
                c = mix(c, C(0.9, 0.9, 0.95), 0.12)
            }
            background[i] = mix(background[i], c, macMask[i])
        }
        gridColor[i] = background[i]
    }
}

let primary = C(0.98, 0.45, 0.32), secondary = C(0.88, 0.25, 0.50), highlight = C(1, 0.84, 0.55)
let aura = C(0.42, 0.62, 1)

func glow(_ out: inout C, dist: Float, along: Float, width: Float, proximity: Float, time: Float) {
    guard proximity > 0.001 else { return }
    let d = dist / width
    guard d < 1 else { return }
    let flow = fbm(along * 3.2, d * 3.2 - time * 0.35)
    let band = max(0.45 * proximity, 0.001)
    let falloff = exp(-d / (band * (0.5 + flow)))
    let fade = 1 - smooth(0.6, 1, d)
    var alpha = clamp(1.1 * proximity * falloff) * fade
    var color = mix(mix(primary, secondary, flow), highlight, falloff * falloff * 0.6)
    let gx = along * 26, gy = d * 13 - time * 3.5
    let (cx, cy) = (floor(gx), floor(gy))
    let center = 0.3 + 0.4 * hash(cx + 7, cy + 7)
    let spark = smooth(0.22, 0, hypot(gx - cx - center, gy - cy - 0.5)) * (hash(cx, cy) > 0.72 ? 1 : 0) * 0.8 *
        proximity * proximity * fade
    color = mix(color, highlight, spark); alpha = clamp(alpha + spark)
    out = out * (1 - alpha) + color * alpha
}

func wave(_ out: inout C, x: Float, y: Float, width: Float, progress: Float, band: Float) {
    guard progress > 0, progress < 1 else { return }
    let eased = 1 - pow(1 - progress, 2.2)
    let sway = (noise(y * 3, progress * 2) - 0.5) * band * 3
    let behind = eased * width * 1.25 + sway - x
    let crest = exp(-behind * behind / (band * band * 0.6))
    let ripple = pow(0.5 + 0.5 * cos(behind / band * 6.2832), 2)
    let wake = behind > 0 ? exp(-behind / (band * 5)) * ripple * 0.45 : 0
    let light = clamp(0.85 * (crest + wake) * (1 - smooth(0.72, 1, progress)))
    out = out * (1 - light) + mix(primary, C(1, 1, 1), crest * 0.6) * light
}

func stamp(
    _ frame: inout [C],
    center: (Float, Float),
    size: Float,
    rotation: Float,
    mask: [Float],
    alpha: Float,
    shader: (Float, Float, C) -> (C, Float)
) {
    let reach = size * 0.75
    let (c, s) = (cos(-rotation), sin(-rotation))
    for y in max(0, Int(center.1 - reach)) ..< min(H, Int(center.1 + reach) + 1) {
        for x in max(0, Int(center.0 - reach)) ..< min(W, Int(center.0 + reach) + 1) {
            let i = y * W + x
            guard mask[i] > 0 else { continue }
            let (dx, dy) = (Float(x) + 0.5 - center.0, Float(y) + 0.5 - center.1)
            let (lx, ly) = (dx * c - dy * s, dx * s + dy * c)
            let u = lx / size + 0.5, v = ly / size + 0.5
            guard u >= 0, u <= 1, v >= 0, v <= 1 else { continue }
            let corner = rounded(lx + size / 2, ly + size / 2, (x: 0, y: 0, w: size, h: size, r: 6))
            let (color, a) = shader(u, v, frame[i])
            let total = corner * a * alpha * mask[i]
            frame[i] = frame[i] * (1 - total) + color * total
        }
    }
}

let dragged = (col: draggedIndex % 3, row: draggedIndex / 3)
let hue = dragged.col + dragged.row * 2 + dragged.row
let startX = phoneRect.x + (Float(dragged.col) + 0.5) * phoneRect.w / 3,
    startY = gridTop + (Float(dragged.row) + 0.5) * cell
let phoneEdge = phoneRect.x + phoneRect.w, macEdge = macRect.x
let release: Float = 2.0, landDuration: Float = 0.9
let size: Float = 64

var out = Data(capacity: W * H * 3)
let total = Int(DURATION * Double(FPS))
let handle = FileHandle.standardOutput
for frameIndex in 0 ..< total {
    let t = Float(frameIndex) / Float(FPS)
    var frame = gridColor
    let lift = smooth(0.5, 0.85, t) * (1 - smooth(release, release + 0.5, t))
    let dragT = smooth(0.9, release, t)
    let bow = sin(dragT * .pi) * -26
    var x = startX + (phoneEdge + 26 - startX) * dragT
    let y = startY + 34 * dragT + bow
    let tau = t - release
    if tau > 0 {
        x = phoneEdge + 26 + 700 * tau
    }
    var proximity = clamp(1 - (phoneEdge - x) / 100)
    if t < 0.9 {
        proximity = 0
    }
    if tau > 0 {
        proximity = clamp((1 + 0.35 * sin(min(tau * 9, .pi))) * exp(-4.5 * tau), 0, 1.35)
    }
    let progress = tau / 0.7
    let tileBack = smooth(release + 0.5, release + 1, t)

    for py in 0 ..< H {
        for px in 0 ..< W {
            let i = py * W + px
            let (fx, fy) = (Float(px) + 0.5, Float(py) + 0.5)
            if phoneMask[i] > 0 {
                var c = frame[i]
                if tileIndex[i] == draggedIndex, t >= 0.5 {
                    c = mix(C(0.02, 0.02, 0.03), c, tileBack)
                }
                c *= 1 - 0.55 * lift
                let along = (fy - phoneRect.y) / phoneRect.h
                glow(&c, dist: phoneEdge - fx, along: along, width: 110, proximity: proximity, time: t)
                wave(&c, x: phoneEdge - fx, y: along, width: phoneRect.w, progress: progress, band: 24)
                let breath = 0.35 + 0.35 * (0.5 + 0.5 * sin(t * 2.09))
                if phoneEdge - fx < 2 {
                    c = mix(c, aura, breath)
                }
                frame[i] = mix(frame[i], c, phoneMask[i])
            }
            if macMask[i] > 0 {
                var c = frame[i]
                let along = (fy - macRect.y) / macRect.h
                glow(&c, dist: fx - macEdge, along: along, width: 110, proximity: proximity, time: t)
                wave(&c, x: fx - macEdge, y: along, width: macRect.w, progress: progress, band: 30)
                let breath = 0.35 + 0.35 * (0.5 + 0.5 * sin(t * 2.09))
                if fx - macEdge < 2 {
                    c = mix(c, aura, breath)
                }
                frame[i] = mix(frame[i], c, macMask[i])
            }
        }
    }

    if t >= 0.5, tau < 0.5 {
        let scale = 1 + 0.06 * lift
        let dissolve = min(proximity, 1)
        let tilt = dragT * (1 - dragT) * 0.6
        stamp(&frame, center: (x, y), size: size * scale, rotation: tilt, mask: phoneMask, alpha: 1) { u, v, _ in
            let grain = noise(u * 18, v * 18) * 0.6 + noise(u * 41, v * 41) * 0.4
            let eaten = dissolve * 1.5 - (1 - u) * 0.5
            let solid = smooth(eaten - 0.12, eaten + 0.12, grain)
            let shift = 0.05 * dissolve * dissolve
            let photoColor = C(
                photo(u + shift, v, hue: hue).x,
                photo(u, v, hue: hue).y,
                photo(u - shift, v, hue: hue).z
            )
            let sheen = 0.28 * exp(-pow(u + v - 1 - dragT * 0.5, 2) * 18) * lift
            let rim = solid * (1 - solid) * 4
            let color = mix(primary, photoColor + C(sheen, sheen, sheen), solid) + primary * rim * 1.4
            return (color, max(solid, rim))
        }
    }

    let targetX = macEdge + 62, targetY = startY + 30
    if t > 0.9, x + size / 2 > phoneEdge, t < 4.7 + 0.4 {
        var mx = macEdge + (x - phoneEdge), my = y
        var condensed = clamp((mx - macEdge + size / 2) / size)
        var pop: Float = 1
        if tau > 0 {
            let fall = exp(-8 * tau) * cos(10 * tau)
            let fromX = macEdge + 26
            mx = targetX + (fromX - targetX) * fall - 40 * tau * exp(-8 * tau) * -1
            my = targetY + (y - targetY) * fall
            condensed = clamp(condensed * 0 + 0.75 + tau * 1.5)
            if tau > 0.45 {
                pop = 1 + 0.12 * exp(-7 * (tau - 0.45)) * smooth(0.45, 0.5, tau)
            }
        }
        let fade = 1 - smooth(4.7, 5.05, t)
        let sheenAt = (tau - 0.65) * 2.4 - 0.2
        stamp(&frame, center: (mx, my), size: size * pop, rotation: 0, mask: macMask, alpha: fade) { u, v, _ in
            let grain = noise(u * 18, v * 18) * 0.6 + noise(u * 41, v * 41) * 0.4
            let solid = smooth(grain - 0.12, grain + 0.12, condensed)
            let rim = solid * (1 - solid) * 4
            var color = mix(primary, photo(u, v, hue: hue), solid) + primary * rim * 1.4
            if tau > 0.65 {
                let sheen = 0.7 * exp(-pow(u + v * 0.35 - sheenAt, 2) * 60)
                color += C(sheen, sheen, sheen)
            }
            return (color, max(solid, 0.45 * (1 - solid)))
        }
    }

    out.removeAll(keepingCapacity: true)
    for pixel in frame {
        out.append(UInt8(clamp(pixel.x) * 255)); out.append(UInt8(clamp(pixel.y) * 255)); out
            .append(UInt8(clamp(pixel.z) * 255))
    }
    handle.write(out)
}
