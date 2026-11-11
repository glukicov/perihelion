import Observation
import PerihelionCore
import QuartzCore
import SwiftUI
import UIKit

struct Spark {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life = 0.0
    var max: Double
    var color: Color
    var size: Double
}

struct Ripple {
    var x: Double
    var y: Double
    var radius: Double
    var grow: Double
    var life = 0.0
    var max: Double
    var color: Color
    var width: Double
}

struct Pop {
    var x: Double
    var y: Double
    var text: String
    var color: Color
    var size: Double
    var italic: Bool
    var life: Double
    var max: Double
}

struct Banner: Equatable {
    var name: String
    var rule: String
}

struct Records {
    private static let hiKey = "perihelion.hi"
    private static let farKey = "perihelion.far"

    var hi: Int
    var far: Int

    static func load() -> Records {
        let d = UserDefaults.standard
        return Records(hi: d.integer(forKey: hiKey), far: d.integer(forKey: farKey))
    }

    func save() {
        let d = UserDefaults.standard
        d.set(hi, forKey: Self.hiKey)
        d.set(far, forKey: Self.farKey)
    }
}

@MainActor
@Observable
final class Session {
    private(set) var game: Game
    private(set) var frame = 0
    private(set) var paused = false
    private(set) var records = Records.load()
    private(set) var newBest = false
    private(set) var banner: Banner?
    private(set) var hint: String?

    private(set) var clock = 0.0
    private(set) var zoom = 1.0
    private(set) var kick = 0.0
    private(set) var shake = 0.0
    private(set) var flash = 0.0
    private(set) var flashColor = Palette.chalk
    private(set) var reveal = 0.0
    private(set) var shown = 0.0
    private(set) var trail: [CGPoint] = []
    private(set) var sparks: [Spark] = []
    private(set) var ripples: [Ripple] = []
    private(set) var pops: [Pop] = []
    private(set) var starPop: [Int: Double] = [:]
    private(set) var aimLit: Aim?
    private(set) var tintFrom = Palette.tints[0]
    private(set) var tintTo = Palette.tints[0]
    private(set) var tintT = 1.0

    @ObservationIgnored private var accumulator = 0.0
    @ObservationIgnored private var slow = 0.0
    @ObservationIgnored private var slowFactor = 1.0
    @ObservationIgnored private var deadAt = 0.0
    @ObservationIgnored private var beatHi = false
    @ObservationIgnored private var coach = false
    @ObservationIgnored private var toldRelease = false
    @ObservationIgnored private var toldFlow = false
    @ObservationIgnored private var bannerUntil = 0.0
    @ObservationIgnored private var hintUntil = Double.infinity
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastTimestamp: CFTimeInterval?
    @ObservationIgnored private let haptics = Haptics()
    @ObservationIgnored let calm = UIAccessibility.isReduceMotionEnabled

    private(set) var viewHeight = 860.0

    init() {
        game = Game(seed: UInt32.random(in: .min ... .max), viewHeight: 860, mode: .title)
        coach = records.far < 5
    }

    var tint: Tint {
        let e = tintT * tintT * (3 - 2 * tintT)
        return tintFrom.mix(tintTo, e)
    }

    var showsHUD: Bool { game.mode != .title }

    func layout(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let scale = min(size.width / Tuning.width, size.height / 560)
        let vh = size.height / scale
        if abs(vh - viewHeight) > 0.5 {
            viewHeight = vh
            game.viewHeight = vh
        }
    }

    func start() {
        guard link == nil else { return }
        let target = LinkTarget { [weak self] link in self?.onFrame(link) }
        let link = CADisplayLink(target: target, selector: #selector(LinkTarget.fire(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func touchDown() {
        guard !paused else { return }
        switch game.mode {
        case .title:
            game.act()
            reveal = max(reveal, 0)
            openingHint()
        case .play:
            game.act()
            handle(game.drainEvents())
        case .dead:
            if clock - deadAt > 0.6 { newGame(mode: .play) }
        }
    }

    func setPaused(_ on: Bool) {
        guard game.mode == .play, paused != on else { return }
        paused = on
        lastTimestamp = nil
    }

    func restart() {
        paused = false
        newGame(mode: .play)
    }

    private func newGame(mode: Mode) {
        game = Game(seed: UInt32.random(in: .min ... .max), viewHeight: viewHeight, mode: mode)
        accumulator = 0
        slow = 0
        zoom = 1
        kick = 0
        shake = 0
        flash = 0
        shown = 0
        trail = []
        sparks = []
        ripples = []
        pops = []
        starPop = [:]
        aimLit = nil
        tintFrom = Palette.tints[0]
        tintTo = Palette.tints[0]
        tintT = 1
        reveal = mode == .title ? 0 : 1
        beatHi = false
        newBest = false
        banner = nil
        coach = records.far < 5
        if mode == .play { openingHint() }
    }

    private func openingHint() {
        if !toldRelease { setHint(coach ? "Tap when the line meets a star" : "Tap to let go") }
    }

    private func setHint(_ text: String?, for seconds: Double = .infinity) {
        hint = text
        hintUntil = clock + seconds
    }

    private func onFrame(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard let last = lastTimestamp else { return }
        step(real: link.timestamp - last)
    }

    private func step(real raw: Double) {
        guard !paused else { return }
        let real = min(0.05, max(0, raw))
        clock += real
        var k = 1.0
        if slow > 0 {
            slow -= real
            k = slowFactor
        }
        accumulator += real * k
        var n = 0
        while accumulator >= Tuning.step && n < 48 {
            game.tick()
            handle(game.drainEvents())
            accumulator -= Tuning.step
            n += 1
        }
        if n >= 48 { accumulator = 0 }
        animate(real)
        #if DEBUG
        autoplay()
        #endif
        frame &+= 1
    }

    #if DEBUG
    @ObservationIgnored private let autoplays = UserDefaults.standard.bool(forKey: "PerihelionAutoplay")

    private func autoplay() {
        guard autoplays else { return }
        switch game.mode {
        case .title:
            if clock > 1.5 { touchDown() }
        case .dead:
            if clock - deadAt > 3 { touchDown() }
        case .play:
            guard let aim = game.castAim(), case .star(let i) = aim.target, i == game.reached + 1 else { return }
            touchDown()
        }
    }
    #endif

    private func animate(_ dt: Double) {
        let c = game.comet
        if game.mode != .title && reveal < 1 { reveal = min(1, reveal + dt * 2.2) }
        let zoomTo = calm || c.star != nil || game.mode == .dead ? 1.0 : 0.955
        zoom += (zoomTo - zoom) * (1 - exp(-dt * 5))
        kick *= exp(-dt * 7)
        shake *= exp(-dt * 9)
        flash *= exp(-dt * 6)
        if tintT < 1 { tintT = min(1, tintT + dt / 1.4) }
        for (key, value) in starPop {
            let next = value * exp(-dt * 8)
            starPop[key] = next > 0.001 ? next : nil
        }

        if game.mode == .dead {
            trail.removeFirst(min(1, trail.count))
        } else {
            trail.append(CGPoint(x: c.x, y: c.y))
            let keep = 26 + game.flow * 4
            if trail.count > keep { trail.removeFirst(trail.count - keep) }
            if c.star == nil && !calm && Double.random(in: 0..<1) < 0.5 {
                sparks.append(Spark(
                    x: c.x, y: c.y,
                    vx: -c.vx * 0.12 + Double.random(in: -20...20), vy: -c.vy * 0.12 + Double.random(in: -20...20),
                    max: 0.3, color: game.flow > 0 ? Palette.comet : Palette.chalk, size: 1.8
                ))
            }
        }

        for k in sparks.indices {
            sparks[k].life += dt
            sparks[k].x += sparks[k].vx * dt
            sparks[k].y += sparks[k].vy * dt
            sparks[k].vx *= 0.97
            sparks[k].vy *= 0.97
        }
        sparks.removeAll { $0.life >= $0.max }
        for k in ripples.indices { ripples[k].life += dt }
        ripples.removeAll { $0.life >= $0.max }
        for k in pops.indices { pops[k].life += dt }
        pops.removeAll { $0.life >= $0.max }

        let score = Double(game.score)
        if shown != score {
            shown += (score - shown) * (1 - exp(-dt * 12))
            if abs(score - shown) < 0.6 { shown = score }
        }

        let coaching = coach && game.reached < 3 && game.mode == .play
        if coaching, let aim = game.castAim(), case .star(let i) = aim.target, i > game.reached {
            aimLit = aim
        } else {
            aimLit = nil
        }

        if banner != nil && clock > bannerUntil { banner = nil }
        if hint != nil && clock > hintUntil { hint = nil }
    }

    private func burst(_ x: Double, _ y: Double, _ count: Int, _ color: Color, _ speed: Double, size: Double = 2.4) {
        let n = calm ? (count + 2) / 3 : count
        for _ in 0..<n {
            let a = Double.random(in: 0..<Tuning.tau)
            let v = speed * Double.random(in: 0.3..<1)
            sparks.append(Spark(
                x: x, y: y, vx: cos(a) * v, vy: sin(a) * v,
                max: Double.random(in: 0.35..<0.85), color: color, size: size
            ))
        }
    }

    private func pop(_ x: Double, _ y: Double, _ text: String, color: Color = Palette.chalk, size: Double = 13,
                     italic: Bool = false, delay: Double = 0, max: Double = 1) {
        pops.append(Pop(
            x: min(Swift.max(x, 64), Tuning.width - 64), y: y, text: text, color: color, size: size,
            italic: italic, life: -delay, max: max
        ))
    }

    private func slowmo(_ seconds: Double, _ factor: Double) {
        guard !calm else { return }
        slow = seconds
        slowFactor = factor
    }

    private func handle(_ events: [GameEvent]) {
        for event in events { handle(event) }
    }

    private func handle(_ event: GameEvent) {
        let c = game.comet
        let flowColor = game.flow > 0 ? Palette.comet : Palette.chalk
        switch event {
        case .release(let auto):
            burst(c.x, c.y, 4, flowColor, 60, size: 2)
            if !auto { haptics.release() }
            if !toldRelease {
                toldRelease = true
                setHint(nil)
            }

        case .capture(let capture):
            guard let s = game.star(capture.star) else { return }
            starPop[s.index] = 1
            ripples.append(Ripple(x: s.x, y: s.y, radius: s.radius, grow: 30, max: 0.5, color: Palette.chalk, width: 1.5))
            burst(c.x, c.y, capture.isNew ? 9 + game.flow * 2 : 5, flowColor, 95)
            kick = capture.deadCentre ? 0.07 : 0.035
            slowmo(capture.deadCentre ? 0.11 : 0.05, 0.3)
            if capture.deadCentre {
                ripples.append(Ripple(
                    x: s.x, y: s.y, radius: s.glyph, grow: s.radius + 30, max: 0.6, color: Palette.comet, width: 2.5
                ))
                flash = 0.4
                flashColor = Palette.chalk
            }
            if capture.isNew {
                let top = s.y - s.radius - 14
                pop(s.x, top, "+" + capture.points.formatted(), color: Palette.comet, size: 15)
                for (k, tag) in capture.tags.enumerated() {
                    pop(s.x, top - 19 * Double(k + 1), tag.label, size: 18, italic: true,
                        delay: 0.07 * Double(k + 1), max: 1.2)
                }
                haptics.capture(centre: capture.deadCentre, flow: game.flow)
                if !beatHi && records.hi > 0 && game.score > records.hi {
                    beatHi = true
                    pop(s.x, top - 19 * Double(capture.tags.count + 1), "New best", color: Palette.comet, size: 18,
                        italic: true, delay: 0.3, max: 1.6)
                }
                if !toldFlow {
                    toldFlow = true
                    setHint("Leave on the first lap for flow", for: 4.5)
                }
            } else {
                haptics.recapture()
                if capture.flowLost { flowLost() }
            }

        case .flowLost:
            flowLost()

        case .knock:
            shake = max(shake, 4)
            burst(c.x, c.y, 5, Palette.chalk, 70, size: 2)
            haptics.knock()

        case .fuse:
            haptics.fuse()

        case .supernova(let index):
            guard let s = game.star(index) else { return }
            ripples.append(Ripple(x: s.x, y: s.y, radius: 8, grow: 150, max: 0.7, color: Palette.ember, width: 3))
            ripples.append(Ripple(x: s.x, y: s.y, radius: 4, grow: 90, max: 0.5, color: Palette.chalk, width: 1.5))
            burst(s.x, s.y, 34, Palette.ember, 230, size: 3)
            burst(s.x, s.y, 12, Palette.chalk, 130)
            shake = 12
            flash = 0.55
            flashColor = Palette.ember
            pop(s.x, s.y - 24, s.name + " burned out", color: Palette.ember, size: 17, italic: true, max: 1.4)
            haptics.supernova()

        case .plate(let plate):
            let info = plate < Catalog.plates.count ? Catalog.plates[plate] : Catalog.offChart
            banner = Banner(name: info.name, rule: info.rule)
            bannerUntil = clock + 2.8
            tintFrom = tint
            tintTo = Palette.tints[plate % Palette.tints.count]
            tintT = 0

        case .died(let death):
            if case .nebula = death {
                ripples.append(Ripple(x: c.x, y: c.y, radius: 4, grow: 46, max: 0.5, color: Palette.chalk, width: 1.5))
                burst(c.x, c.y, 14, Palette.chalk, 110)
            }
            shake = max(shake, 7)
            finish()
        }
    }

    private func flowLost() {
        let c = game.comet
        pop(c.x, c.y - 22, "Flow lost", color: Palette.ember, size: 16, italic: true)
    }

    private func finish() {
        newBest = game.score > records.hi && game.score > 0
        if game.score > records.hi { records.hi = game.score }
        if game.reached > records.far { records.far = game.reached }
        records.save()
        shown = Double(game.score)
        deadAt = clock
        hint = nil
        haptics.death()
    }
}

@MainActor
private final class LinkTarget: NSObject {
    let handler: (CADisplayLink) -> Void

    init(_ handler: @escaping (CADisplayLink) -> Void) {
        self.handler = handler
    }

    @objc func fire(_ link: CADisplayLink) {
        handler(link)
    }
}
