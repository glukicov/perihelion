import AppKit
import CoreGraphics

let size = 1024
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let space = CGColorSpaceCreateDeviceRGB()
guard let cg = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("no context") }

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let s = Double(size)
let ground = CGGradient(
    colorsSpace: space, colors: [rgb(30, 70, 124), rgb(14, 40, 80), rgb(8, 24, 54)] as CFArray, locations: [0, 0.6, 1]
)!
cg.drawRadialGradient(
    ground, startCenter: CGPoint(x: s * 0.42, y: s * 0.6), startRadius: 0,
    endCenter: CGPoint(x: s * 0.5, y: s * 0.5), endRadius: s * 0.75, options: [.drawsAfterEndLocation]
)

cg.setStrokeColor(rgb(237, 242, 244, 0.07))
cg.setLineWidth(3)
for k in 1..<4 {
    let v = s * Double(k) / 4
    cg.move(to: CGPoint(x: v, y: 0))
    cg.addLine(to: CGPoint(x: v, y: s))
    cg.move(to: CGPoint(x: 0, y: v))
    cg.addLine(to: CGPoint(x: s, y: v))
}
cg.strokePath()

var seed: UInt64 = 42
func rand() -> Double {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Double(seed >> 11) / Double(1 << 53)
}
for _ in 0..<60 {
    let d = 2 + rand() * 5
    cg.setFillColor(rgb(237, 242, 244, 0.2 + rand() * 0.4))
    cg.fill(CGRect(x: rand() * s, y: rand() * s, width: d, height: d))
}

let centre = CGPoint(x: s * 0.5, y: s * 0.44)
let ring = s * 0.29
cg.setStrokeColor(rgb(237, 242, 244, 0.55))
cg.setLineWidth(9)
cg.setLineDash(phase: 0, lengths: [26, 30])
cg.addEllipse(in: CGRect(x: centre.x - ring, y: centre.y - ring, width: 2 * ring, height: 2 * ring))
cg.strokePath()
cg.setLineDash(phase: 0, lengths: [])

cg.setStrokeColor(rgb(237, 242, 244))
cg.setLineWidth(14)
cg.addEllipse(in: CGRect(x: centre.x - 62, y: centre.y - 62, width: 124, height: 124))
cg.strokePath()
cg.setFillColor(rgb(237, 242, 244))
cg.fillEllipse(in: CGRect(x: centre.x - 20, y: centre.y - 20, width: 40, height: 40))

let a0 = Double.pi * 0.95
let a1 = Double.pi * 0.35
cg.setStrokeColor(rgb(244, 201, 93, 0.95))
cg.setLineWidth(22)
cg.setLineCap(.round)
cg.addArc(center: centre, radius: ring, startAngle: a0, endAngle: a1, clockwise: true)
cg.strokePath()

let comet = CGPoint(x: centre.x + cos(a1) * ring, y: centre.y + sin(a1) * ring)
let glow = CGGradient(
    colorsSpace: space, colors: [rgb(244, 201, 93, 0.85), rgb(244, 201, 93, 0.25), rgb(244, 201, 93, 0)] as CFArray,
    locations: [0, 0.35, 1]
)!
cg.drawRadialGradient(glow, startCenter: comet, startRadius: 0, endCenter: comet, endRadius: 150, options: [])
cg.setFillColor(rgb(244, 201, 93))
cg.fillEllipse(in: CGRect(x: comet.x - 44, y: comet.y - 44, width: 88, height: 88))
cg.setFillColor(rgb(237, 242, 244))
cg.fillEllipse(in: CGRect(x: comet.x - 19, y: comet.y - 19, width: 38, height: 38))

let dx = -sin(a1)
let dy = cos(a1)
for k in 1...7 {
    let d = 70 + Double(k) * 52
    let r = 11 - Double(k) * 1.1
    cg.setFillColor(rgb(244, 201, 93, 0.95 - Double(k) * 0.1))
    cg.fillEllipse(in: CGRect(x: comet.x + dx * d - r, y: comet.y + dy * d - r, width: 2 * r, height: 2 * r))
}

guard let image = cg.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
else { fatalError("no image") }
try png.write(to: out)
print("wrote \(out.path)")
