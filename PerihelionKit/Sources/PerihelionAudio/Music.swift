import PerihelionCore

/// What the web synth plays. The presentation layer maps engine events onto these.
public enum SynthCue: Equatable, Sendable {
    case release
    case pluck(step: Int, bell: Bool)
    case newBest
    case recapture
    case flowLost
    case knock
    case fuse(left: Double)
    case supernova
    case plate
    case died(inNebula: Bool)
    case chime
}

/// The pentatonic the web `SCALE` array climbs as flow builds.
public enum SynthScale {
    public static let notes: [Double] = [
        293.66, 329.63, 369.99, 440, 493.88, 587.33, 659.25, 739.99, 880, 987.77, 1174.66,
    ]

    /// `flow < MAX_FLOW ? flow : MAX_FLOW + starIndex % 4`, clamped to the scale.
    public static func pluckStep(flow: Int, starIndex: Int, maxFlow: Int = Tuning.maxFlow) -> Int {
        let step = flow < maxFlow ? flow : maxFlow + (starIndex % 4)
        return min(max(step, 0), notes.count - 1)
    }

    public static func frequency(forStep step: Int) -> Double {
        notes[min(max(step, 0), notes.count - 1)]
    }
}

/// Drone levels from the web `Snd.mood`: gain, low-pass cutoff, shimmer into the reverb.
public struct PadLevels: Equatable, Sendable {
    public var gain: Double
    public var cutoff: Double
    public var shimmer: Double

    public init(gain: Double, cutoff: Double, shimmer: Double) {
        self.gain = gain
        self.cutoff = cutoff
        self.shimmer = shimmer
    }

    public static func levels(live: Bool, title: Bool, flow: Int, maxFlow: Int = Tuning.maxFlow) -> PadLevels {
        let capped = min(max(flow, 0), max(maxFlow, 1))
        let f = Double(capped) / Double(max(maxFlow, 1))
        let gain = live ? 0.07 + f * 0.05 : title ? 0.045 : 0.02
        let cutoff = 420 + (live ? f * 900 : 0)
        let shimmer = live ? f * f * 0.012 : 0
        return PadLevels(gain: gain, cutoff: cutoff, shimmer: shimmer)
    }
}
