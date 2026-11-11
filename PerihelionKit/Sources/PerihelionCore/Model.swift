import Foundation

public struct Star: Sendable, Identifiable {
    public let index: Int
    public let name: String
    public let bayer: String
    public let spectralClass: String
    public let magnitude: Double
    public let kind: StarKind
    public internal(set) var x: Double
    public let homeX: Double
    public let y: Double
    public internal(set) var radius: Double
    public internal(set) var spin: Double
    public let driftAmplitude: Double
    public let driftPhase: Double
    public let driftSpeed: Double
    public internal(set) var fuse: Double
    public internal(set) var fuseTotal: Double
    public let glyph: Double
    public let labelOnRight: Bool
    public internal(set) var charted: Bool
    public internal(set) var chartedAt: Double
    public internal(set) var dead: Bool

    public var id: Int { index }
    public var subtitle: String { bayer.isEmpty ? "" : bayer + " · " + spectralClass }
    public var catchRadius: Double { radius + Tuning.catchMargin }
    public var lap: Double { Tuning.tau + spin * Tuning.lapGrace }
}

public struct Nebula: Sendable {
    public let x: Double
    public let y: Double
    public let radius: Double
    public let name: String
    public let seed: Double
}

public struct Link: Sendable {
    public let from: Int
    public let to: Int
    public let toY: Double
    public let drawnAt: Double
}

public struct Comet: Sendable {
    public internal(set) var x: Double
    public internal(set) var y: Double
    public internal(set) var vx: Double = 0
    public internal(set) var vy: Double = 0
    public internal(set) var star: Int?
    public internal(set) var orbitRadius: Double
    public internal(set) var angle: Double = -Double.pi / 2
    public internal(set) var direction: Double = 1
    public internal(set) var leaving: Int?
    public internal(set) var flungBy: Int?
    public internal(set) var flown: Double = 0
    public internal(set) var swept: Double = 0
    public internal(set) var lapOpen = true
    public internal(set) var swift = true
    public internal(set) var bounces = 0
}

public struct Stats: Sendable, Equatable, Codable {
    public internal(set) var centres = 0
    public internal(set) var banks = 0
    public internal(set) var skips = 0
    public internal(set) var bestFlow = 0
}

public enum Mode: String, Sendable, Codable {
    case title, play, dead
}

public enum CaptureTag: Equatable, Sendable {
    case skipped(Int)
    case bankShot
    case deadCentre

    public var label: String {
        switch self {
        case .skipped(let n): "Skipped \(n)"
        case .bankShot: "Bank shot"
        case .deadCentre: "Dead centre"
        }
    }
}

public struct Capture: Equatable, Sendable {
    public let star: Int
    public let isNew: Bool
    public let points: Int
    public let tags: [CaptureTag]
    public let deadCentre: Bool
    public let flowLost: Bool
}

public enum Death: Equatable, Sendable {
    case lost
    case nebula(String)
}

public enum GameEvent: Equatable, Sendable {
    case release(auto: Bool)
    case capture(Capture)
    case flowLost
    case knock
    case fuse(left: Double)
    case supernova(star: Int)
    case plate(Int)
    case died(Death)
    /// A miss that spent a life and put the comet back on the last star caught.
    case lifeLost(Death)
    /// A milestone restored one life, still capped at the run's starting count.
    case lifeGained
}

public enum AimTarget: Sendable {
    case star(Int)
    case nebula(Int)
}

public struct Aim: Sendable {
    public let target: AimTarget
    public let distance: Double
}
