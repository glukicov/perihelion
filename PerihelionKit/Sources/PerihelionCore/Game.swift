import Foundation

public struct Game: Sendable {
    public private(set) var mode: Mode
    public private(set) var time = 0.0
    public private(set) var stars: [Star] = []
    public private(set) var nebulae: [Nebula] = []
    public private(set) var links: [Link] = []
    public private(set) var comet: Comet
    public private(set) var cameraY = 0.0
    public private(set) var cameraTarget = 0.0
    public private(set) var score = 0
    public private(set) var reached = 0
    public private(set) var flow = 0
    public private(set) var plate = 0
    public private(set) var stats = Stats()
    public private(set) var cause = ""
    public private(set) var lives: Int
    public private(set) var maxLives: Int
    public private(set) var options: RunOptions
    public private(set) var events: [GameEvent] = []
    public var viewHeight: Double {
        didSet { if mode == .title { cameraY = titleCamera; cameraTarget = cameraY } }
    }

    private var rng: Mulberry32
    private var nebulaCount = 0
    private var lastCharted = 0

    public init(seed: UInt32, viewHeight: Double, mode: Mode = .play, options: RunOptions = .standard) {
        self.rng = Mulberry32(seed: seed)
        self.viewHeight = viewHeight
        self.mode = mode
        self.options = options
        self.lives = options.startingLives
        self.maxLives = options.startingLives
        self.comet = Comet(x: 0, y: 0, orbitRadius: 0)
        let sol = makeStar(0, previous: nil)
        stars.append(sol)
        comet = Comet(x: sol.x, y: sol.y - sol.radius, star: 0, orbitRadius: sol.radius)
        if mode == .title {
            cameraY = titleCamera
            cameraTarget = cameraY
        }
        ensureStars()
    }

    public var titleCamera: Double { (Tuning.anchor - 0.5) * viewHeight }

    public func star(_ index: Int) -> Star? {
        guard let first = stars.first?.index else { return nil }
        let k = index - first
        return stars.indices.contains(k) ? stars[k] : nil
    }

    public var orbiting: Star? { comet.star.flatMap(star) }

    public mutating func drainEvents() -> [GameEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    public mutating func act() {
        switch mode {
        case .title:
            cameraTarget = 0
            mode = .play
        case .play:
            if comet.star != nil { release(auto: false) }
        case .dead:
            break
        }
    }

    public mutating func tick() {
        let dt = Tuning.step
        advanceRules(dt)
        cameraY += (cameraTarget - cameraY) * (1 - exp(-dt * Tuning.cameraRate))
        ensureStars()
    }

    private func slot(_ index: Int) -> Int { index - stars[0].index }

    private mutating func makeStar(_ i: Int, previous prev: Star?) -> Star {
        let name: String
        let bayer: String
        let cls: String
        let mag: Double
        let kind: StarKind
        if i < Catalog.stars.count {
            let entry = Catalog.stars[i]
            name = entry.name
            bayer = entry.bayer
            cls = entry.spectralClass
            mag = entry.magnitude
            kind = i == 0 ? .sol : StarKind.of(spectralClass: cls)
        } else {
            let r = rng.next()
            name = "Uncharted \(i)"
            bayer = ""
            cls = ""
            mag = 2 + Double(i - Catalog.stars.count + 1) * 0.01
            kind = r < 0.25 ? .red : r < 0.6 ? .blue : .white
        }
        let w = Tuning.width
        var radius = i == 0 ? 62 : max(40, 60 - Double(i) * 0.45) * kind.radiusScale
        var spin = (2.3 + Double(min(i, 40)) * 0.026) * kind.spinScale
        let chartedFuse = i == 0
            ? Double.infinity
            : max(max(3.2, 7.5 - Double(i) * 0.1) * kind.fuseScale, 1.7 * Tuning.tau / spin)
        if options.difficulty != 1 {
            radius /= options.difficulty
            spin *= options.difficulty
        }
        var x = w / 2
        var y = 0.0
        if let prev {
            let gap = max(175 + Double(min(i, 30)) * 1.2 + rng.next() * 50, prev.radius + radius + 62)
            y = prev.y - gap
            let lo = radius + 26
            let hi = w - radius - 26
            var tries = 0
            repeat {
                x = lo + rng.next() * (hi - lo)
                tries += 1
            } while tries < 14 && (abs(x - prev.homeX) < 36 || abs(x - prev.homeX) > 190)
        }
        var amp = 0.0
        if i > Tuning.starsPerPlate && rng.next() < (i <= 16 ? 0.4 : i <= 24 ? 0.5 : 0.65) {
            amp = min(18 + rng.next() * 27, x - radius - 12, w - radius - 12 - x)
            if amp < 8 { amp = 0 }
        }
        let fuse = options.difficulty == 1 || chartedFuse.isInfinite ? chartedFuse : chartedFuse / options.difficulty
        let sub = bayer.isEmpty ? "" : bayer + " · " + cls
        let labelWidth = max(Double(name.utf16.count) * 7.6, Double(sub.utf16.count) * 5.8) + 8
        let roomRight = w - 4 - (x + amp + radius + 11)
        let roomLeft = x - amp - radius - 11 - 4
        let fitsRight = roomRight >= labelWidth
        let fitsLeft = roomLeft >= labelWidth
        let labelOnRight = fitsRight && fitsLeft ? x < w / 2 : fitsRight ? true : fitsLeft ? false : roomRight > roomLeft
        let phase = rng.next() * Tuning.tau
        let speed = (0.7 + rng.next() * 0.6) * (i > 24 ? 1.25 : 1)
        let glyph = i == 0 ? 13 : min(max(7 + (2.2 - mag) * 2.2, 6), 15) * (kind == .red ? 1.25 : 1)
        return Star(
            index: i, name: name, bayer: bayer, spectralClass: cls, magnitude: mag, kind: kind,
            x: x, homeX: x, y: y, radius: radius, spin: spin,
            driftAmplitude: amp, driftPhase: phase, driftSpeed: speed,
            fuse: fuse, fuseTotal: fuse, glyph: glyph, labelOnRight: labelOnRight,
            charted: i == 0, chartedAt: -9, dead: false
        )
    }

    private mutating func maybeNebula(between a: Star, and b: Star) {
        if b.index <= 16 || rng.next() >= (b.index <= 24 ? 0.45 : 0.6) { return }
        let dx = b.homeX - a.homeX
        let dy = b.y - a.y
        let len = hypot(dx, dy)
        let nx = -dy / len
        let ny = dx / len
        let t = 0.42 + rng.next() * 0.16
        let r = 11 + rng.next() * 4
        let off = (b.index <= 24 ? 50 : 42) + rng.next() * 24
        var side: Double = rng.next() < 0.5 ? -1 : 1
        for _ in 0..<2 {
            defer { side = -side }
            let x = a.homeX + dx * t + nx * off * side
            let y = a.y + dy * t + ny * off * side
            if x < r + 14 || x > Tuning.width - r - 14 { continue }
            if hypot(x - a.homeX, y - a.y) < a.radius + a.driftAmplitude + r + 16 { continue }
            if hypot(x - b.homeX, y - b.y) < b.radius + b.driftAmplitude + r + 16 { continue }
            let name = Catalog.nebulae[nebulaCount % Catalog.nebulae.count]
            nebulaCount += 1
            nebulae.append(Nebula(x: x, y: y, radius: r, name: name, seed: rng.next() * 1000))
            return
        }
    }

    private mutating func ensureStars() {
        var last = stars[stars.count - 1]
        while last.y > cameraY - viewHeight * 1.6 - 400 {
            let s = makeStar(last.index + 1, previous: last)
            maybeNebula(between: last, and: s)
            stars.append(s)
            last = s
        }
        let floor = cameraY + viewHeight * (1 - Tuning.anchor) + 500
        while stars.count > 4 && stars[0].y > floor && stars[0].index != comet.star && !anchors(stars[0].index) {
            stars.removeFirst()
        }
        if let first = nebulae.first, first.y > floor { nebulae.removeFirst() }
        if let first = links.first, first.toY > floor { links.removeFirst() }
    }

    /// A multi-life run keeps the furthest star on the chart, so a miss can return there.
    private func anchors(_ index: Int) -> Bool {
        maxLives > 1 && index == reached
    }

    public mutating func apply(_ update: RunOptions) {
        if update.startingLives != maxLives {
            lives = update.startingLives
        }
        maxLives = update.startingLives
        let previous = options.difficulty
        options = update
        guard previous != update.difficulty, previous > 0 else { return }
        let radiusScale = previous / update.difficulty
        let spinScale = update.difficulty / previous
        for i in stars.indices {
            stars[i].radius *= radiusScale
            stars[i].spin *= spinScale
            if stars[i].fuse.isFinite {
                stars[i].fuse *= radiusScale
                stars[i].fuseTotal *= radiusScale
            }
        }
        guard comet.star != nil else { return }
        comet.orbitRadius *= radiusScale
        if let index = comet.star, let s = star(index) {
            comet.x = s.x + cos(comet.angle) * comet.orbitRadius
            comet.y = s.y + sin(comet.angle) * comet.orbitRadius
        }
    }

    private mutating func release(auto: Bool) {
        guard let index = comet.star else { return }
        var speed = 460 + Double(min(reached, 40)) * 4
        if options.difficulty != 1 { speed *= options.difficulty }
        comet.vx = -sin(comet.angle) * comet.direction * speed
        comet.vy = cos(comet.angle) * comet.direction * speed
        comet.swift = index == 0 || comet.lapOpen
        comet.star = nil
        comet.leaving = index
        comet.flungBy = auto ? index : nil
        comet.flown = 0
        comet.bounces = 0
        events.append(.release(auto: auto))
    }

    private mutating func capture(_ k: Int, distance d: Double) {
        let s = stars[k]
        let speed = hypot(comet.vx, comet.vy)
        let safeSpeed = speed == 0 ? 1 : speed
        let rx = comet.x - s.x
        let ry = comet.y - s.y
        let cross = rx * comet.vy - ry * comet.vx
        let off = abs(cross) / safeSpeed / s.catchRadius
        let isNew = s.index > reached

        comet.star = s.index
        comet.orbitRadius = d
        comet.angle = atan2(ry, rx)
        comet.direction = cross >= 0 ? 1 : -1
        comet.swept = 0
        comet.leaving = nil
        comet.flungBy = nil
        cameraTarget = s.y
        if !s.charted {
            stars[k].charted = true
            stars[k].chartedAt = time
        }

        var points = 0
        var tags: [CaptureTag] = []
        var centre = false
        var lost = false
        var newPlate: Int?
        if isNew {
            let n = s.index - reached
            if comet.swift { flow = min(Tuning.maxFlow, flow + 1) }
            stats.bestFlow = max(stats.bestFlow, flow)
            let m = 1 + flow
            points = 10 * n * m
            if n >= 2 {
                points += 25 * m
                tags.append(.skipped(n - 1))
                stats.skips += 1
            }
            if comet.bounces > 0 {
                points += 15 * m
                tags.append(.bankShot)
                stats.banks += 1
            }
            if off < Tuning.centre {
                points += 10 * m
                tags.append(.deadCentre)
                centre = true
                stats.centres += 1
            }
            score += points
            links.append(Link(from: lastCharted, to: s.index, toY: s.y, drawnAt: time))
            lastCharted = s.index
            reached = s.index
            comet.lapOpen = true
            let p = (s.index - 1) / Tuning.starsPerPlate
            if p > plate {
                plate = p
                newPlate = p
            }
        } else {
            comet.lapOpen = false
            if flow > 0 {
                flow = 0
                lost = true
            }
        }
        comet.bounces = 0
        events.append(.capture(Capture(
            star: s.index, isNew: isNew, points: points, tags: tags, deadCentre: centre, flowLost: lost
        )))
        if let newPlate { events.append(.plate(newPlate)) }
        if isNew && reached > 0 && reached.isMultiple(of: Tuning.lifeMilestone) && lives < maxLives {
            lives += 1
            events.append(.lifeGained)
        }
    }

    private mutating func fail(_ death: Death) {
        guard lives > 1 else {
            lives = 0
            die(death)
            return
        }
        lives -= 1
        events.append(.lifeLost(death))
        restoreCheckpoint()
    }

    private func checkpointIndex() -> Int? {
        if star(reached) != nil { return reached }
        return stars.map(\.index).filter { $0 <= reached }.max()
    }

    private mutating func restoreCheckpoint() {
        guard let index = checkpointIndex() else {
            lives = 0
            die(.lost)
            return
        }
        let k = slot(index)
        if stars[k].dead {
            stars[k].dead = false
            let lap = 1.7 * Tuning.tau / max(stars[k].spin, 0.01)
            let half = stars[k].fuseTotal.isFinite ? stars[k].fuseTotal * 0.5 : lap
            stars[k].fuse = max(half, lap)
        }
        let s = stars[k]
        flow = 0
        comet = Comet(x: s.x, y: s.y - s.radius, star: s.index, orbitRadius: s.radius)
        cameraTarget = s.y
        cameraY = s.y
    }

    private mutating func die(_ death: Death) {
        switch death {
        case .nebula(let name): cause = "Lost in the " + name
        case .lost: cause = comet.flungBy.map { Catalog.starName($0) + " burned out" } ?? "Lost in the dark"
        }
        mode = .dead
        events.append(.died(death))
    }

    private mutating func advanceRules(_ dt: Double) {
        time += dt
        for k in stars.indices where stars[k].driftAmplitude != 0 {
            let s = stars[k]
            stars[k].x = s.homeX + s.driftAmplitude * sin(s.driftPhase + time * s.driftSpeed)
        }
        if mode == .dead { return }

        if let index = comet.star {
            let k = slot(index)
            let s = stars[k]
            let da = s.spin * dt
            comet.orbitRadius += (s.radius - comet.orbitRadius) * (1 - exp(-dt * 9))
            comet.angle += comet.direction * da
            comet.swept += da
            comet.x = s.x + cos(comet.angle) * comet.orbitRadius
            comet.y = s.y + sin(comet.angle) * comet.orbitRadius
            if mode != .play || s.index == 0 { return }
            if comet.lapOpen && comet.swept >= s.lap {
                comet.lapOpen = false
                if flow > 0 {
                    flow = 0
                    events.append(.flowLost)
                }
            }
            let before = s.fuse
            stars[k].fuse -= dt
            let after = stars[k].fuse
            if after < 1.5 && (before / 0.25).rounded(.down) != (after / 0.25).rounded(.down) {
                events.append(.fuse(left: after))
            }
            if after <= 0 {
                stars[k].dead = true
                release(auto: true)
                events.append(.supernova(star: index))
            }
            return
        }

        comet.flown += hypot(comet.vx, comet.vy) * dt
        comet.x += comet.vx * dt
        comet.y += comet.vy * dt
        let w = Tuning.width
        if comet.x < Tuning.wall {
            comet.x = Tuning.wall
            comet.vx = abs(comet.vx)
            comet.bounces += 1
            events.append(.knock)
        } else if comet.x > w - Tuning.wall {
            comet.x = w - Tuning.wall
            comet.vx = -abs(comet.vx)
            comet.bounces += 1
            events.append(.knock)
        }
        if let leaving = comet.leaving {
            if let from = star(leaving) {
                if hypot(comet.x - from.x, comet.y - from.y) > from.radius + 12 { comet.leaving = nil }
            }
        }
        for b in nebulae where hypot(comet.x - b.x, comet.y - b.y) < b.radius {
            fail(.nebula(b.name))
            return
        }
        for k in stars.indices {
            let s = stars[k]
            if s.dead || s.index == comet.leaving { continue }
            let d = hypot(comet.x - s.x, comet.y - s.y)
            if d < s.catchRadius {
                capture(k, distance: d)
                return
            }
        }
        cameraTarget = min(cameraTarget, comet.y)
        if comet.y > cameraY + viewHeight * (1 - Tuning.anchor) + 30 || comet.flown > options.cometRange {
            fail(.lost)
        }
    }

    public func castAim() -> Aim? {
        guard let index = comet.star else { return nil }
        var x = comet.x
        var y = comet.y
        var dx = -sin(comet.angle) * comet.direction
        let dy = cos(comet.angle) * comet.direction
        var from: Int? = index
        let w = Tuning.width
        var d = 0.0
        while d < options.cometRange {
            x += dx * 3
            y += dy * 3
            if x < Tuning.wall {
                x = Tuning.wall
                dx = abs(dx)
            } else if x > w - Tuning.wall {
                x = w - Tuning.wall
                dx = -abs(dx)
            }
            for (k, b) in nebulae.enumerated() where hypot(x - b.x, y - b.y) < b.radius + 2 {
                return Aim(target: .nebula(k), distance: d)
            }
            if let f = from, let s = star(f), hypot(x - s.x, y - s.y) > s.radius + 12 { from = nil }
            for s in stars where !s.dead && s.index != from {
                if hypot(x - s.x, y - s.y) < s.catchRadius { return Aim(target: .star(s.index), distance: d) }
            }
            d += 3
        }
        return nil
    }
}
