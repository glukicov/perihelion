import Foundation
import Testing

@testable import PerihelionCore

struct Fixture: Decodable {
    struct Event: Decodable {
        let tick: Int
        let type: String
        let x: Double
        let y: Double
        let auto: Bool?
        let star: Int?
        let isNew: Bool?
        let points: Int?
        let tags: [String]?
        let centre: Bool?
        let lost: Bool?
        let left: Double?
        let plate: Int?
        let kind: String?
        let cause: String?
    }

    struct AimRecord: Decodable, Equatable {
        let star: Int?
        let nebula: Int?
        let d: Double
    }

    struct Checkpoint: Decodable {
        let tick: Int
        let x: Double
        let y: Double
        let camY: Double
        let score: Int
        let reached: Int
        let flow: Int
        let stars: Int
        let nebulae: Int
        let firstStar: Int
        let aim: AimRecord?
    }

    struct Final: Decodable {
        let mode: String
        let score: Int
        let reached: Int
        let flow: Int
        let plate: Int
        let cause: String
        let stats: Stats
    }

    let name: String
    let seed: UInt32
    let mode: String
    let viewHeight: Double
    let ticks: Int
    let taps: [Int]
    let events: [Event]
    let checkpoints: [Checkpoint]
    let final: Final

    static let names = [
        "steady", "greedy", "hesitant", "wild", "title-then-burnout", "deep", "reckless", "horsehead", "snake",
    ]

    static func load(_ name: String) throws -> Fixture {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }
}

struct Observed {
    let tick: Int
    let event: GameEvent
    let x: Double
    let y: Double
}

func describe(_ event: GameEvent) -> String {
    switch event {
    case .release: "release"
    case .capture: "capture"
    case .flowLost: "flowlost"
    case .knock: "knock"
    case .fuse: "fuse"
    case .supernova: "supernova"
    case .plate: "plate"
    case .died: "die"
    }
}

func close(_ a: Double, _ b: Double, _ tolerance: Double = 2e-6) -> Bool {
    abs(a - b) <= tolerance
}

func mismatch(_ expected: Fixture.Event, _ got: Observed) -> String? {
    let place = "tick \(expected.tick) \(expected.type)"
    guard got.tick == expected.tick, describe(got.event) == expected.type else {
        return "\(place): got \(describe(got.event)) at tick \(got.tick)"
    }
    guard close(got.x, expected.x), close(got.y, expected.y) else {
        return "\(place): comet at (\(got.x), \(got.y)), expected (\(expected.x), \(expected.y))"
    }
    switch got.event {
    case .release(let auto):
        if auto != expected.auto { return "\(place): auto \(auto)" }
    case .capture(let c):
        let ok = c.star == expected.star && c.isNew == expected.isNew && c.points == expected.points
            && c.tags.map(\.label) == expected.tags && c.deadCentre == expected.centre && c.flowLost == expected.lost
        if !ok { return "\(place): \(c) vs star \(expected.star ?? -1) points \(expected.points ?? -1) \(expected.tags ?? [])" }
    case .fuse(let left):
        if !close(left, expected.left ?? .nan) { return "\(place): fuse \(left) vs \(expected.left ?? .nan)" }
    case .supernova(let star):
        if star != expected.star { return "\(place): star \(star)" }
    case .plate(let plate):
        if plate != expected.plate { return "\(place): plate \(plate)" }
    case .died(let death):
        let kind = death == .lost ? "lost" : "blot"
        if kind != expected.kind { return "\(place): death \(death)" }
    case .flowLost, .knock:
        break
    }
    return nil
}

func aimRecord(_ game: Game) -> Fixture.AimRecord? {
    guard let aim = game.castAim() else { return nil }
    switch aim.target {
    case .star(let i): return .init(star: i, nebula: nil, d: aim.distance)
    case .nebula(let k): return .init(star: nil, nebula: k, d: aim.distance)
    }
}

struct ReplayTests {
    @Test(arguments: Fixture.names)
    func replayMatchesWebRules(name: String) throws {
        let fixture = try Fixture.load(name)
        var game = Game(
            seed: fixture.seed, viewHeight: fixture.viewHeight, mode: fixture.mode == "title" ? .title : .play
        )
        let taps = Set(fixture.taps)
        var checkpoints = fixture.checkpoints.makeIterator()
        var nextCheckpoint = checkpoints.next()
        var expected = fixture.events.makeIterator()
        var tick = 0
        var compared = 0

        while tick < 120 * 300 && game.mode != .dead {
            var batches: [([GameEvent], Double, Double)] = []
            if taps.contains(tick) {
                game.act()
                batches.append((game.drainEvents(), game.comet.x, game.comet.y))
            }
            game.tick()
            batches.append((game.drainEvents(), game.comet.x, game.comet.y))
            for (events, x, y) in batches {
                for event in events {
                let observed = Observed(tick: tick, event: event, x: x, y: y)
                guard let want = expected.next() else {
                    Issue.record("\(name): unexpected \(describe(event)) at tick \(tick)")
                    return
                }
                if let problem = mismatch(want, observed) {
                    Issue.record("\(name): \(problem)")
                    return
                }
                compared += 1
                }
            }
            if let cp = nextCheckpoint, cp.tick == tick {
                let ok = close(game.comet.x, cp.x) && close(game.comet.y, cp.y) && close(game.cameraY, cp.camY)
                    && game.score == cp.score && game.reached == cp.reached && game.flow == cp.flow
                    && game.stars.count == cp.stars && game.nebulae.count == cp.nebulae
                    && game.stars.first?.index == cp.firstStar && aimRecord(game) == cp.aim
                if !ok {
                    Issue.record("\(name): checkpoint at tick \(tick) differs: \(cp) vs aim \(String(describing: aimRecord(game)))")
                    return
                }
                nextCheckpoint = checkpoints.next()
            }
            tick += 1
        }

        #expect(expected.next() == nil, "\(name): web run has more events than the Swift run")
        #expect(nextCheckpoint == nil, "\(name): missed checkpoints")
        #expect(compared == fixture.events.count)
        #expect(tick == fixture.ticks)
        #expect(game.mode.rawValue == fixture.final.mode)
        #expect(game.score == fixture.final.score)
        #expect(game.reached == fixture.final.reached)
        #expect(game.flow == fixture.final.flow)
        #expect(game.plate == fixture.final.plate)
        #expect(game.cause == fixture.final.cause)
        #expect(game.stats == fixture.final.stats)
    }
}
