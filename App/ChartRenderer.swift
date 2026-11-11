import PerihelionCore
import SwiftUI

@MainActor
enum Textures {
    static let grain: Image = {
        let n = 256
        guard let cg = CGContext(
            data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Image(systemName: "circle") }
        guard let data = cg.data else { return Image(systemName: "circle") }
        let pixels = data.bindMemory(to: UInt8.self, capacity: n * n * 4)
        var rng = Mulberry32(seed: 7)
        for k in 0..<(n * n) {
            let light = rng.next() < 0.5
            let alpha = UInt8(rng.next() * (light ? 11 : 20))
            let value = light ? alpha : 0
            pixels[4 * k] = value
            pixels[4 * k + 1] = value
            pixels[4 * k + 2] = value
            pixels[4 * k + 3] = alpha
        }
        guard let made = cg.makeImage() else { return Image(systemName: "circle") }
        return Image(decorative: made, scale: 1)
    }()

    static let wash: Image = {
        let w = 256
        let h = 512
        let space = CGColorSpaceCreateDeviceRGB()
        guard let cg = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Image(systemName: "circle") }
        var rng = Mulberry32(seed: 11)
        for k in 0..<10 {
            let x = rng.next() * Double(w)
            let y = rng.next() * Double(h)
            let r = 50 + rng.next() * 95
            let light = k % 3 != 0
            let inner = light
                ? CGColor(red: 214 / 255, green: 232 / 255, blue: 1, alpha: 0.085)
                : CGColor(red: 0, green: 4 / 255, blue: 20 / 255, alpha: 0.2)
            let outer = inner.copy(alpha: 0) ?? inner
            guard let gradient = CGGradient(colorsSpace: space, colors: [inner, outer] as CFArray, locations: [0, 1])
            else { continue }
            for oy in [-h, 0, h] {
                for ox in [-w, 0, w] {
                    let c = CGPoint(x: x + Double(ox), y: Double(h) - (y + Double(oy)))
                    cg.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
                }
            }
        }
        guard let made = cg.makeImage() else { return Image(systemName: "circle") }
        return Image(decorative: made, scale: 1)
    }()
}

func chartHash(_ n: Double) -> Double {
    let x = sin(n * 127.1 + 311.7) * 43758.5453
    return x - x.rounded(.down)
}

func tintColor(_ kind: StarKind) -> Color {
    switch kind {
    case .red: Palette.ember
    case .blue: Palette.ice
    case .sol, .white: Palette.chalk
    }
}

func glyphPath(x: Double, y: Double, size: Double, kind: StarKind) -> Path {
    var p = Path()
    let n = kind == .blue ? 8 : 16
    for k in 0..<n {
        let a = Double(k) * Tuning.tau / Double(n) - Double.pi / 2
        let rr: Double = kind == .blue
            ? (k % 2 == 1 ? size * 0.2 : size * 1.25)
            : (k % 2 == 1 ? size * 0.24 : (k % 4 != 0 ? size * 0.56 : size))
        let pt = CGPoint(x: x + cos(a) * rr, y: y + sin(a) * rr)
        if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
}

func drawGlyph(_ g: GraphicsContext, x: Double, y: Double, size: Double, kind: StarKind, charted: Bool, color: Color,
               lineWidth: Double) {
    let circle = { (r: Double) in Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)) }
    switch kind {
    case .sol:
        g.stroke(circle(size), with: .color(color), lineWidth: lineWidth)
        g.fill(circle(3), with: .color(color))
    case .red:
        g.stroke(circle(size), with: .color(color), lineWidth: lineWidth)
        g.fill(circle(size * (charted ? 0.55 : 0.2)), with: .color(color))
    case .white, .blue:
        let path = glyphPath(x: x, y: y, size: size, kind: kind)
        if charted { g.fill(path, with: .color(color)) } else { g.stroke(path, with: .color(color), lineWidth: lineWidth) }
    }
}

@MainActor
enum ChartRenderer {
    static let anchor = Tuning.anchor
    static let width = Tuning.width

    static func draw(_ base: GraphicsContext, size: CGSize, session s: Session) {
        let game = s.game
        let tint = s.tint
        let scale = min(size.width / width, size.height / 560)
        let vh = size.height / scale

        base.fill(Path(CGRect(origin: .zero, size: size)), with: .color(tint.ground.color))

        let tileH = size.width * 2
        var wy = (((-game.cameraY * scale * 0.45).truncatingRemainder(dividingBy: tileH)) + tileH)
            .truncatingRemainder(dividingBy: tileH) - tileH
        while wy < size.height {
            base.draw(Textures.wash, in: CGRect(x: 0, y: wy, width: size.width, height: tileH))
            wy += tileH
        }
        let grainTile = 128.0
        let off = (((-game.cameraY * scale).truncatingRemainder(dividingBy: grainTile)) + grainTile)
            .truncatingRemainder(dividingBy: grainTile)
        var gy = off - grainTile
        while gy < size.height {
            var gx = 0.0
            while gx < size.width {
                base.draw(Textures.grain, in: CGRect(x: gx, y: gy, width: grainTile, height: grainTile))
                gx += grainTile
            }
            gy += grainTile
        }

        let z = s.zoom + s.kick
        let sx = s.calm ? 0 : Double.random(in: -0.5...0.5) * s.shake
        let sy = s.calm ? 0 : Double.random(in: -0.5...0.5) * s.shake
        var g = base
        g.translateBy(x: size.width / 2 - width / 2 * scale * z + sx, y: size.height * anchor - game.cameraY * scale * z + sy)
        g.scaleBy(x: scale * z, y: scale * z)

        let top = game.cameraY - vh * anchor / z - 10
        let bottom = game.cameraY + vh * (1 - anchor) / z + 10

        drawChart(g, top: top, bottom: bottom)
        drawLinks(g, session: s)
        for b in game.nebulae where b.y > top - 40 && b.y < bottom + 40 {
            drawNebula(g, b, ink: tint.ink.color, session: s)
        }
        for star in game.stars where !(star.y + star.radius < top - 30 || star.y - star.radius > bottom + 30) {
            drawStar(g, star, session: s)
        }
        for r in s.ripples {
            let f = r.life / r.max
            let radius = r.radius + (1 - (1 - f) * (1 - f)) * r.grow
            var rg = g
            rg.opacity = 0.7 * (1 - f)
            rg.stroke(circle(r.x, r.y, radius), with: .color(r.color), lineWidth: r.width)
        }
        if let orbiting = game.orbiting, game.mode != .dead {
            if let lit = s.aimLit {
                drawPreview(g, session: s, length: lit.distance, lit: true)
            } else {
                drawPreview(g, session: s, length: max(130, 250 - Double(orbiting.index) * 4), lit: false)
            }
        }
        drawComet(g, session: s)
        for p in s.sparks {
            var pg = g
            pg.opacity = 1 - p.life / p.max
            pg.fill(Path(CGRect(x: p.x - p.size / 2, y: p.y - p.size / 2, width: p.size, height: p.size)), with: .color(p.color))
        }
        for p in s.pops where p.life >= 0 {
            let f = p.life / p.max
            var pg = g
            pg.opacity = 1 - f * f * f
            let font = p.italic ? Palette.display(p.size) : Palette.mono(p.size, weight: .medium)
            pg.draw(
                Text(p.text).font(font).foregroundStyle(p.color),
                at: CGPoint(x: p.x, y: p.y - (1 - (1 - f) * (1 - f)) * 26), anchor: .bottom
            )
        }
        if s.flash > 0.01 && !s.calm {
            var fg = base
            fg.opacity = s.flash * 0.3
            fg.fill(Path(CGRect(origin: .zero, size: size)), with: .color(s.flashColor))
        }
    }

    private static func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }

    private static func drawChart(_ g: GraphicsContext, top: Double, bottom: Double) {
        var grid = Path()
        var y = (top / 100).rounded(.down) * 100
        while y < bottom {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: width, y: y))
            y += 100
        }
        var x = 100.0
        while x < width {
            grid.move(to: CGPoint(x: x, y: top))
            grid.addLine(to: CGPoint(x: x, y: bottom))
            x += 100
        }
        var gg = g
        gg.opacity = 0.07
        gg.stroke(grid, with: .color(Palette.chalk), lineWidth: 0.6)

        var ticks = Path()
        y = (top / 20).rounded(.down) * 20
        while y < bottom {
            let len = y.truncatingRemainder(dividingBy: 100) == 0 ? 10.0 : 4.0
            ticks.move(to: CGPoint(x: 0, y: y))
            ticks.addLine(to: CGPoint(x: len, y: y))
            ticks.move(to: CGPoint(x: width, y: y))
            ticks.addLine(to: CGPoint(x: width - len, y: y))
            y += 20
        }
        ticks.move(to: CGPoint(x: 0, y: top))
        ticks.addLine(to: CGPoint(x: 0, y: bottom))
        ticks.move(to: CGPoint(x: width, y: top))
        ticks.addLine(to: CGPoint(x: width, y: bottom))
        var tg = g
        tg.opacity = 0.34
        tg.stroke(ticks, with: .color(Palette.chalk), lineWidth: 0.8)

        var row = (top / 60).rounded(.down)
        while row * 60 < bottom {
            for k in 0..<3 {
                let n = row * 3 + Double(k)
                let dx = 14 + chartHash(n) * (width - 28)
                let dy = row * 60 + chartHash(n + 0.5) * 60
                let size = 0.7 + chartHash(n + 0.25) * 1.3
                var dg = g
                dg.opacity = 0.18 + chartHash(n + 0.75) * 0.34
                dg.fill(Path(CGRect(x: dx - size / 2, y: dy - size / 2, width: size, height: size)), with: .color(Palette.chalk))
            }
            row += 1
        }
    }

    private static func drawLinks(_ g: GraphicsContext, session s: Session) {
        var path = Path()
        for link in s.game.links {
            guard let a = s.game.star(link.from), let b = s.game.star(link.to) else { continue }
            let dx = b.x - a.x
            let dy = b.y - a.y
            let len = hypot(dx, dy)
            let from = a.radius + 7
            let to = len - b.radius - 7
            if to <= from { continue }
            let p = min(max((s.game.time - link.drawnAt) / 0.5, 0), 1)
            let ux = dx / len
            let uy = dy / len
            let end = from + (to - from) * p
            path.move(to: CGPoint(x: a.x + ux * from, y: a.y + uy * from))
            path.addLine(to: CGPoint(x: a.x + ux * end, y: a.y + uy * end))
        }
        var lg = g
        lg.opacity = 0.3
        lg.stroke(path, with: .color(Palette.chalk), lineWidth: 0.9)
    }

    private static func drawNebula(_ g: GraphicsContext, _ b: Nebula, ink: Color, session s: Session) {
        let wobble = s.calm ? 0 : sin(s.clock * 1.7 + b.seed) * 0.6
        let n = 16
        func pt(_ k: Int) -> CGPoint {
            let a = Double(k % n) / Double(n) * Tuning.tau
            let rr = b.radius + 3 + wobble + (chartHash(b.seed + Double(k % n) * 3.1) - 0.5) * 7
            return CGPoint(x: b.x + cos(a) * rr, y: b.y + sin(a) * rr)
        }
        func mid(_ p: CGPoint, _ q: CGPoint) -> CGPoint { CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2) }
        var path = Path()
        path.move(to: mid(pt(0), pt(1)))
        for k in 1...n {
            path.addQuadCurve(to: mid(pt(k), pt(k + 1)), control: pt(k))
        }
        var bg = g
        bg.opacity = 0.95 * s.reveal
        bg.fill(path, with: .color(ink))
        for k in 0..<6 {
            let a = chartHash(b.seed + Double(k) * 7.7) * Tuning.tau
            let d = b.radius + 7 + chartHash(b.seed + Double(k) * 1.3) * 8
            bg.fill(circle(b.x + cos(a) * d, b.y + sin(a) * d, 0.8 + chartHash(b.seed + Double(k)) * 1.8), with: .color(ink))
        }
        var tg = g
        tg.opacity = 0.5 * s.reveal
        tg.draw(
            Text(b.name).font(Palette.display(11)).foregroundStyle(Palette.chalk),
            at: CGPoint(x: min(max(b.x, 44), width - 44), y: b.y + b.radius + 22), anchor: .bottom
        )
    }

    private static func drawStar(_ g: GraphicsContext, _ star: Star, session s: Session) {
        let game = s.game
        let c = game.comet
        let fade = star.index == 0 ? 1 : s.reveal
        guard fade > 0 else { return }
        let current = star.index == c.star
        let low = star.fuse < star.fuseTotal * 0.3
        let throb = low ? 0.6 + 0.4 * sin(game.time * 22) : 1

        if star.dead {
            var cross = Path()
            cross.move(to: CGPoint(x: star.x - 6, y: star.y - 6))
            cross.addLine(to: CGPoint(x: star.x + 6, y: star.y + 6))
            cross.move(to: CGPoint(x: star.x + 6, y: star.y - 6))
            cross.addLine(to: CGPoint(x: star.x - 6, y: star.y + 6))
            var dg = g
            dg.opacity = 0.5 * fade
            dg.stroke(cross, with: .color(Palette.ember), lineWidth: 1.2)
        } else {
            let dash: [CGFloat] = star.kind == .red ? [8, 5] : star.kind == .blue ? [1.5, 3.5] : [3, 5]
            var rg = g
            rg.opacity = (current ? 0.55 : 0.34) * fade * throb
            rg.stroke(
                circle(star.x, star.y, star.radius), with: .color(low ? Palette.ember : Palette.chalk),
                style: StrokeStyle(lineWidth: 1, dash: dash)
            )

            if let lit = s.aimLit, case .star(let i) = lit.target, i == star.index {
                var lg = g
                lg.opacity = 0.6 + 0.4 * sin(s.clock * 14)
                lg.stroke(circle(star.x, star.y, star.radius), with: .color(Palette.comet), lineWidth: 2.5)
            }

            if current && c.lapOpen && star.index > 0 && game.mode == .play {
                let left = min(star.lap - c.swept, Tuning.tau - 0.001)
                if left > 0 {
                    var arc = Path()
                    arc.addArc(
                        center: CGPoint(x: star.x, y: star.y), radius: star.radius,
                        startAngle: .radians(c.angle), endAngle: .radians(c.angle + c.direction * left),
                        clockwise: c.direction < 0
                    )
                    var ag = g
                    ag.opacity = 0.9
                    ag.stroke(arc, with: .color(Palette.comet), lineWidth: 2.2)
                }
            }

            if star.fuse < star.fuseTotal {
                var arc = Path()
                let share = min(max(star.fuse / star.fuseTotal, 0), 1)
                arc.addArc(
                    center: CGPoint(x: star.x, y: star.y), radius: star.glyph + 8,
                    startAngle: .radians(-Double.pi / 2), endAngle: .radians(-Double.pi / 2 + Tuning.tau * share),
                    clockwise: false
                )
                var fg = g
                fg.opacity = 0.9 * fade * throb
                fg.stroke(arc, with: .color(low ? Palette.ember : Palette.chalk), lineWidth: 2.2)
            }

            var sg = g
            sg.opacity = fade
            let breathe = current && !s.calm ? 1 + 0.07 * sin(game.time * 6) : 1
            let pop = s.starPop[star.index] ?? 0
            drawGlyph(
                sg, x: star.x, y: star.y, size: star.glyph * breathe * (1 + pop * 0.5), kind: star.kind,
                charted: star.charted, color: tintColor(star.kind), lineWidth: 1.1
            )
        }

        if star.charted {
            let ink = min(max((game.time - star.chartedAt) / 0.4, 0), 1) * fade * (star.dead ? 0.45 : 1)
            let lx = star.labelOnRight ? star.x + star.radius + 11 : star.x - star.radius - 11
            let anchor: UnitPoint = star.labelOnRight ? .bottomLeading : .bottomTrailing
            var tg = g
            tg.opacity = ink
            tg.draw(Text(star.name).font(Palette.display(16)).foregroundStyle(Palette.chalk),
                    at: CGPoint(x: lx, y: star.y + 4), anchor: anchor)
            if !star.subtitle.isEmpty {
                tg.opacity = ink * 0.62
                let mag = String(format: "mag %.2f", star.magnitude).replacingOccurrences(of: "-", with: "−")
                tg.draw(Text(star.subtitle).font(Palette.mono(9.5)).foregroundStyle(Palette.chalk),
                        at: CGPoint(x: lx, y: star.y + 17), anchor: anchor)
                tg.draw(Text(mag).font(Palette.mono(9.5)).foregroundStyle(Palette.chalk),
                        at: CGPoint(x: lx, y: star.y + 29), anchor: anchor)
            }
        }
    }

    private static func drawPreview(_ g: GraphicsContext, session s: Session, length: Double, lit: Bool) {
        let c = s.game.comet
        var x = c.x
        var y = c.y
        var dx = -sin(c.angle) * c.direction
        let dy = cos(c.angle) * c.direction
        let gap = lit ? 7.0 : 10.0
        var run = s.calm ? 6 : 6 + (s.clock * 46).truncatingRemainder(dividingBy: gap)
        var done = 0.0
        let wall = Tuning.wall
        let r = lit ? 2.0 : 1.35
        var leg = 0
        while leg < 4 && done < length - 0.5 {
            var reach = length - done
            if dx > 1e-6 {
                reach = min(reach, (width - wall - x) / dx)
            } else if dx < -1e-6 {
                reach = min(reach, (wall - x) / dx)
            }
            reach = max(0, reach)
            while run < reach {
                var dg = g
                dg.opacity = lit ? 0.95 : 0.75 * (1 - (done + run) / length)
                dg.fill(circle(x + dx * run, y + dy * run, r), with: .color(Palette.comet))
                run += gap
            }
            run -= reach
            x += dx * reach
            y += dy * reach
            done += reach
            dx = -dx
            leg += 1
        }
    }

    private static func drawComet(_ g: GraphicsContext, session s: Session) {
        let game = s.game
        let c = game.comet
        let fade = c.star != nil ? 1 : min(max((Tuning.range - c.flown) / 150, 0), 1)
        let color = game.flow > 0 ? Palette.comet : Palette.chalk
        let n = s.trail.count
        if n > 1 {
            for k in 1..<n {
                let f = Double(k) / Double(n)
                var path = Path()
                path.move(to: s.trail[k - 1])
                path.addLine(to: s.trail[k])
                var tg = g
                tg.opacity = f * f * 0.6 * fade
                tg.stroke(path, with: .color(color),
                          style: StrokeStyle(lineWidth: 0.6 + f * (5 + Double(game.flow) * 0.5), lineCap: .round))
            }
        }
        guard game.mode != .dead else { return }
        let size = 30 + Double(game.flow) * 3.5
        var glow = g
        glow.opacity = fade
        glow.blendMode = .plusLighter
        glow.fill(
            circle(c.x, c.y, size / 2),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Palette.comet.opacity(0.75), location: 0),
                    .init(color: Palette.comet.opacity(0.22), location: 0.35),
                    .init(color: Palette.comet.opacity(0), location: 1),
                ]),
                center: CGPoint(x: c.x, y: c.y), startRadius: 0, endRadius: size / 2
            )
        )
        var body = g
        body.opacity = fade
        body.fill(circle(c.x, c.y, 5.2), with: .color(Palette.comet))
        body.fill(circle(c.x, c.y, 2.2), with: .color(Palette.chalk))
    }
}
