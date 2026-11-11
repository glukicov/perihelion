# Porting Perihelion: notes from the first milestone

Perihelion started life as a single HTML file built in a chat over two evenings. The goal of this repo is a proper
native iPhone game with *exactly* the same rules. Milestone one is the boring, load-bearing part: a pure Swift rules
engine, and a test that proves it plays the same game as the web version.

This page is the long version of the README: how the check works, what it found, and what it costs.

## The shape of the engine

`PerihelionKit/Sources/PerihelionCore` is plain Swift with no UIKit, SpriteKit or SwiftUI imports:

- `Game` is a value type. `tick()` advances one fixed step of 1/120 s; `act()` is the single button.
- Randomness is `Mulberry32`, a bit-exact port of the generator in the web file (tested against JavaScript's own
  output for three seeds).
- Everything the presentation needs comes out of `drainEvents()`: `release`, `capture`, `flowLost`, `knock`, `fuse`,
  `supernova`, `plate` and `died`. Sound, haptics and particles will listen to these and nothing else.
- `castAim()` returns where the comet would go if you let go now, for the dotted aim line.

Stars refer to each other by index rather than by object, which is the main structural change from the JavaScript.
The rest is a line-by-line port of `makeStar`, `maybeNebula`, `ensureStars`, `release`, `capture`, `die`, `tick` and
`castAim`.

## How "plays the same game" is checked

`tools/reference.mjs` cuts the rules section straight out of `web/perihelion-2d.html` (by its section markers, so
the reference is the shipped code, not a copy of it), stubs out the DOM, and drives it one tick at a time. An
autoplayer decides when to let go and records each tap as a tick number. The output, one JSON file per run, is:

- the list of tap ticks
- every event with its tick and the comet's position
- a checkpoint every 2 seconds: position, camera, score, flow, how many stars and nebulae are alive, and what the aim
  line is pointing at
- the final score, furthest star, plate, cause of death and stats

`ReplayTests` replays the same taps into the Swift `Game` and requires the same events at the same ticks, positions
within 2×10⁻⁶ units, the same checkpoints and the same ending. Nine runs cover drift, nebulae, burn-outs, skips, bank
shots, dead centres, recaptures by old stars, the title screen, every plate, and the uncharted stars past the
catalogue. The three longest runs last the full five minutes of game time and pass star 370.

## Finding 1: the web game plays a different game in JavaScriptCore and V8

The first version of the harness ran in Node, and the Swift replays drifted: by 3×10⁻⁶ units after ~3,000 ticks,
then by 0.035 units 600 ticks later. Exponential growth is the signature of chaos, not of a bug. Each capture turns a
tiny position error into an angle error, and 540 units of flight turn that back into a bigger position error.

The seed of the error is the maths library. Comparing 200,000 random inputs bit for bit between V8 (Node 22) and
Apple's libm (which Swift uses):

| Function | Inputs where V8 and Apple's libm differ |
|---|---:|
| `hypot` | 38.6% |
| `atan2` | 13.4% |
| `exp` | 10.9% |
| `sin` | 5.0% |
| `cos` | 4.4% |

Always in the last bit, and always enough. Safari's JavaScriptCore uses the system libm, so I ran the same harness
under the `jsc` shell that ships with macOS, and compared it with V8:

| Run | Safari engine score | V8 score | V8 first differs at tick |
|---|---:|---:|---:|
| steady | 66,110 | 67,510 | 2,857 |
| greedy | 80,290 | 79,930 | 6,200 |
| deep | 82,025 | 85,465 | 4,713 |
| reckless | 14,465 | 35,615 | 2,758 |
| five shorter runs | same | same | never |

So the web version has no single "correct" long run: the same seed and the same taps give a different game in each
browser after a minute or so of play. The fixtures therefore come from JavaScriptCore, the engine the web game uses
on an iPhone, and the Swift engine matches it on every run.

Nobody will notice this while playing, because a human never repeats a run tick for tick. It matters the day runs
are replayed or compared across devices: ghosts, daily seeds, or checking a leaderboard score by replaying it. If
that day comes, the fix is to ship our own `sin`, `cos`, `atan2`, `exp` and `hypot` (fdlibm ports) in both engines.

Caveat: "V8" here is Node 22's V8. Chrome uses V8 too, but I haven't checked a Chrome build directly.

## Finding 2: the aim line fibs after a wall bounce

The first autoplayer let go whenever the coaching aim line pointed at the next star, and it kept dying with "Lost in
the dark" just after a wall knock. The aim line is cast in 3-unit steps and the comet moves about 4 units per tick,
and both clamp to the wall rather than reflecting the overshoot. The two folded paths can end up a few units apart,
which is enough to graze past a star you were promised.

The reference autoplayer now predicts by simulating real ticks, and the aim line is noted as a candidate fix for the
game itself. Fixing it would change the rules' cousin, not the rules, so it can wait for a deliberate decision.

## Finding 3: one rule leaned on the screen

Dropping off the bottom of the screen ends a run, and "the bottom" depends on the camera, which the web version
eases once per rendered frame using the real frame time and the window height. The rules were quietly frame-rate
dependent. The Swift engine eases the camera once per tick at a fixed view height, so a run is the same at 60 Hz,
120 Hz or in a test. The reference harness does the same, which is why the replays can match at all.

## Milestone two: the iPhone app

The app in `App/` is a thin layer over the engine. A `CADisplayLink` asks for up to 120 Hz and feeds real time into
fixed engine ticks, slowed to ×0.3 for a moment after each catch, exactly as the web frame loop does. Effects
(sparks, ripples, pop-up tags, shake, flash, haptics) only listen to engine events, and the chart is drawn with
SwiftUI `Canvas` in chart units under one transform, so the drawing code reads almost line for line like the web
`draw()`.

Two small lessons from the simulator. A paper-grain texture built from a raw pixel buffer turned the whole chart a
pale grey-blue, while the same pixels written through a Core Graphics context looked right; and the simulator
panel's screenshots can trail the real screen by a second, so `xcrun simctl io screenshot` is the source of truth.

## What's next

- Game Center for best scores
- The 3D version later, on the same engine

Sound (the plucked pentatonic, the drone that opens with flow, whooshes, knocks, and a generated reverb) and the
real fonts (IM Fell English and DM Mono) now live in the app. Haptics use Core Haptics on the same moments the
soundtrack marks. A real phone is still the place to judge the mix, the Taptic Engine, and ProMotion.
