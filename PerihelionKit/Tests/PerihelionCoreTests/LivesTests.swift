import Foundation
import Testing

@testable import PerihelionCore

struct LivesTests {
    @Test func standardPlayStartsWithThreeLives() {
        let game = Game(seed: 1, viewHeight: 800, mode: .play)
        #expect(game.lives == 3)
        #expect(game.maxLives == 3)
        #expect(game.options == .standard)
    }

    @Test func classicRunStillDiesOnTheFirstMiss() throws {
        var game = try makeGame(lives: 1, range: 320)
        game.act()
        let ticks = try flyUntilStopped(&game)
        #expect(game.mode == .dead)
        #expect(game.lives == 0)
        #expect(game.cause == "Lost in the dark")
        #expect(ticks > 0)
        #expect(game.events.contains { if case .died(.lost) = $0 { true } else { false } })
    }

    @Test func aMissSpendsOneLifeAndReturnsToTheLastStar() throws {
        var game = try makeGame(lives: 3, range: 320)
        game.act()
        _ = try flyUntilStopped(&game)

        #expect(game.mode == .play)
        #expect(game.lives == 2)
        #expect(game.maxLives == 3)
        #expect(game.score == 0)
        #expect(game.reached == 0)
        #expect(game.flow == 0)
        let sol = try #require(game.star(0))
        #expect(game.comet.star == 0)
        #expect(game.comet.x == sol.x)
        #expect(game.comet.y == sol.y - sol.radius)
        #expect(game.cameraY == sol.y)
        #expect(game.cause == "")
    }

    @Test func theRunEndsOnlyWhenTheLastLifeIsSpent() throws {
        var game = try makeGame(lives: 3, range: 320)
        for livesLeft in [2, 1] {
            game.act()
            _ = try flyUntilStopped(&game)
            let batch = game.drainEvents()
            #expect(game.mode == .play)
            #expect(game.lives == livesLeft)
            #expect(batch.contains { if case .lifeLost(.lost) = $0 { true } else { false } })
            #expect(!batch.contains { if case .died = $0 { true } else { false } })
        }
        game.act()
        _ = try flyUntilStopped(&game)
        let batch = game.drainEvents()
        #expect(game.mode == .dead)
        #expect(game.lives == 0)
        #expect(game.cause == "Lost in the dark")
        #expect(batch.contains { if case .died(.lost) = $0 { true } else { false } })
        #expect(game.comet.star == nil)
    }

    @Test func aCaughtStarIsKeptWhenTheNextFlightIsLost() throws {
        var game = try makeGame(lives: 3, range: Tuning.range)
        let caught = try chase(&game, to: 1)
        #expect(caught)
        let score = game.score
        try releaseIntoTheDark(&game)
        _ = try flyUntilStopped(&game)
        #expect(game.mode == .play)
        #expect(game.lives == 2)
        #expect(game.reached == 1)
        #expect(game.score == score)
        #expect(game.comet.star == 1)
    }

    @Test func everyFourthStarRestoresOneLifeUpToTheStart() throws {
        var game = try makeGame(lives: 3, range: 320)
        game.act()
        _ = try flyUntilStopped(&game)
        #expect(game.lives == 2)

        game.apply(RunOptions(startingLives: 3, difficulty: 1, cometRange: Tuning.range))
        #expect(game.lives == 2)

        let reachedThree = try chase(&game, to: 3)
        #expect(reachedThree)
        #expect(game.lives == 2)

        var gained = false
        var ticks = 0
        while game.reached < 4 && game.mode != .dead && ticks < 120 * 60 {
            if game.comet.star != nil { steer(&game) }
            game.tick()
            let events = game.drainEvents()
            if events.contains(where: { if case .lifeGained = $0 { true } else { false } }) {
                gained = true
                #expect(game.reached == 4)
                #expect(game.lives == 3)
            }
            ticks += 1
        }
        #expect(gained)
        #expect(game.lives == 3)

        let before = game.lives
        let reachedEight = try chase(&game, to: 8)
        #expect(reachedEight)
        #expect(game.lives == before)
    }

    @Test func aBurnedOutCheckpointReignites() throws {
        var game = try makeGame(lives: 3, range: Tuning.range)
        #expect(try chase(&game, to: 1))
        var ticks = 0
        var supernova = false
        while !supernova && ticks < 120 * 20 {
            game.tick()
            supernova = game.drainEvents().contains { if case .supernova(1) = $0 { true } else { false } }
            ticks += 1
        }
        #expect(supernova)
        #expect(game.star(1)?.dead == true)

        _ = try flyUntilStopped(&game)
        if game.mode == .play && game.comet.star == 1 {
            let star = try #require(game.star(1))
            #expect(star.dead == false)
            #expect(star.fuse > 1)
            #expect(game.lives == 2)
        } else if game.reached > 1 {
            // The fling found another star. The burned one stays spent; the run did not end.
            #expect(game.mode == .play)
            #expect(game.lives == 3)
        } else {
            Issue.record("expected a checkpoint on Sirius or a new catch, mode \(game.mode) reached \(game.reached)")
        }
    }

    @Test func difficultyScalesTheChartAndLeavesTheOriginalUntouched() throws {
        let classic = Game(seed: 11, viewHeight: 780, mode: .play, options: .classic)
        let harsh = Game(
            seed: 11, viewHeight: 780, mode: .play,
            options: RunOptions(startingLives: 1, difficulty: 1.25, cometRange: Tuning.range)
        )
        let sirius = try #require(classic.star(1))
        let harder = try #require(harsh.star(1))
        let base = max(40, 60 - 0.45)
        #expect(sirius.radius == base)
        #expect(abs(harder.radius - base / 1.25) < 1e-9)
        #expect(harder.spin == sirius.spin * 1.25)
        #expect(harder.fuse < sirius.fuse)

        let again = Game(seed: 11, viewHeight: 780, mode: .play, options: .classic)
        #expect(again.star(4)?.x == classic.star(4)?.x)
        #expect(again.star(4)?.y == classic.star(4)?.y)
        #expect(again.star(4)?.radius == classic.star(4)?.radius)
    }

    @Test func aShorterReachIsLostSoonerThanTheChartedOne() throws {
        var short = try makeGame(lives: 1, range: 320)
        short.act()
        let shortTicks = try flyUntilStopped(&short)
        #expect(short.mode == .dead)

        var charted = try makeGame(lives: 1, range: Tuning.range)
        charted.act()
        var ticks = 0
        while ticks < shortTicks {
            charted.tick()
            _ = charted.drainEvents()
            ticks += 1
        }
        #expect(charted.mode == .play)
    }

    @Test func movingTheLifeSliderSetsTheHeartsYouHave() throws {
        var game = try makeGame(lives: 3, range: 320)
        game.act()
        _ = try flyUntilStopped(&game)
        #expect(game.lives == 2)
        game.apply(RunOptions(startingLives: 5, difficulty: 1, cometRange: 320))
        #expect(game.lives == 5)
        #expect(game.maxLives == 5)
        game.apply(RunOptions(startingLives: 5, difficulty: 1, cometRange: 400))
        #expect(game.lives == 5)
        game.apply(RunOptions(startingLives: 1, difficulty: 1, cometRange: 400))
        #expect(game.lives == 1)
        #expect(game.maxLives == 1)
    }

    @Test func settingsRoundTripThroughUserDefaults() {
        let name = "perihelion.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        #expect(RunOptions.load(from: defaults) == .standard)

        let chosen = RunOptions(startingLives: 7, difficulty: 0.8, cometRange: 400)
        chosen.save(to: defaults)
        #expect(RunOptions.load(from: defaults) == chosen)

        RunOptions(startingLives: 0, difficulty: 4, cometRange: 20).save(to: defaults)
        let stored = RunOptions.load(from: defaults)
        #expect(stored.startingLives == 1)
        #expect(stored.difficulty == Tuning.difficultyMax)
        #expect(stored.cometRange == Tuning.cometRangeMin)
        defaults.removePersistentDomain(forName: name)
    }
}

private func makeGame(lives: Int, range: Double) throws -> Game {
    Game(
        seed: 3, viewHeight: 800, mode: .play,
        options: RunOptions(startingLives: lives, difficulty: 1, cometRange: range)
    )
}

@discardableResult
private func flyUntilStopped(_ game: inout Game) throws -> Int {
    var ticks = 0
    while game.mode != .dead && game.comet.star == nil && ticks < 4_000 {
        game.tick()
        ticks += 1
    }
    if ticks == 4_000 { Issue.record("flight did not end") }
    return ticks
}

private func steer(_ game: inout Game) {
    if let aim = game.castAim(), case .star(let index) = aim.target, index > game.reached {
        game.act()
        return
    }
    if let star = game.orbiting, star.fuse < 1.2 {
        game.act()
    }
}

private func chase(_ game: inout Game, to star: Int) throws -> Bool {
    var ticks = 0
    while game.reached < star && game.mode != .dead && ticks < 120 * 90 {
        if game.comet.star != nil { steer(&game) }
        game.tick()
        _ = game.drainEvents()
        ticks += 1
    }
    return game.reached >= star && game.mode != .dead
}

private func releaseIntoTheDark(_ game: inout Game) throws {
    var ticks = 0
    while game.comet.star != nil && ticks < 5_000 {
        if game.castAim() == nil {
            game.act()
            return
        }
        game.tick()
        _ = game.drainEvents()
        ticks += 1
    }
    game.act()
}
