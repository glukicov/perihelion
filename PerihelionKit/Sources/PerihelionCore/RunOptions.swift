import Foundation

/// How a run is allowed to feel. The charted rules are difficulty 1 and a reach of
/// `Tuning.range`. Lives are attempts: the comet can be lost that many times.
public struct RunOptions: Sendable, Equatable {
    public var startingLives: Int
    public var difficulty: Double
    public var cometRange: Double

    /// What the app offers before anyone has moved a slider: three lives, the original chart.
    public static let standard = RunOptions(startingLives: 3, difficulty: 1, cometRange: Tuning.range)

    /// The one-life chart the web game plays, and the one the replay fixtures record.
    public static let classic = RunOptions(startingLives: 1, difficulty: 1, cometRange: Tuning.range)

    public init(startingLives: Int, difficulty: Double, cometRange: Double) {
        self.startingLives = min(Tuning.maxStartingLives, max(1, startingLives))
        self.difficulty = min(Tuning.difficultyMax, max(Tuning.difficultyMin, difficulty))
        self.cometRange = min(Tuning.cometRangeMax, max(Tuning.cometRangeMin, cometRange))
    }

    public static func load(from defaults: UserDefaults = .standard) -> RunOptions {
        var lives = standard.startingLives
        var difficulty = standard.difficulty
        var range = standard.cometRange
        if defaults.object(forKey: Key.lives) != nil { lives = defaults.integer(forKey: Key.lives) }
        if defaults.object(forKey: Key.difficulty) != nil { difficulty = defaults.double(forKey: Key.difficulty) }
        if defaults.object(forKey: Key.range) != nil { range = defaults.double(forKey: Key.range) }
        return RunOptions(startingLives: lives, difficulty: difficulty, cometRange: range)
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(startingLives, forKey: Key.lives)
        defaults.set(difficulty, forKey: Key.difficulty)
        defaults.set(cometRange, forKey: Key.range)
    }

    private enum Key {
        static let lives = "perihelion.lives"
        static let difficulty = "perihelion.difficulty"
        static let range = "perihelion.range"
    }
}
