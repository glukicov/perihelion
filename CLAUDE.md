# Perihelion: from a web demo to a native iOS game

## Where this came from

Perihelion began as a browser game built in a chat (10 and 11 Nov 2026) as an experimental demo. This repo turns it into a proper iOS game built in Xcode. Two working web versions live in `web/`:

- `web/perihelion-2d.html`: the flat star-chart version
- `web/perihelion-3d.html`: the same rules in a three.js 3D scene

Each is a single self-contained HTML file: open it in a browser, click or press Space to act, Escape to pause. The 3D file loads three.js r128 from cdnjs. These files are the reference spec; when the docs and the code disagree, the code is right.

## Status

- **Decided:** port the 2D game first; the 3D game can follow later on the same engine.
- **Done:** milestone one, the rules engine in `PerihelionKit/Sources/PerihelionCore`, verified by replay tests against the web rules (see `docs/WRITEUP.md`).
- **Done:** milestone two, a playable iPhone app in `App/` (SwiftUI `Canvas` driven by `CADisplayLink`, haptics, pause, records, app icon). Play-tested in the iPhone 17 simulator, including a debug autoplayer (`just autoplay`).
- **Next:** Game Center. Sound (AVAudioEngine, the WebAudio synth including generated reverb), IM Fell English, DM Mono, and the rest of the 2D presentation are in the app.

## App structure

- `project.yml` is the source of truth for `Perihelion.xcodeproj` (regenerate with `just project`, which runs XcodeGen; commit both).
- `App/Session.swift`: the frame clock (real time with slow motion into fixed engine ticks), effects state and the event handlers, ported from the web `frame`, `animate` and `emit`.
- `App/ChartRenderer.swift`: the port of the web `draw()` onto `GraphicsContext`, in chart units under one world transform.
- `App/GameView.swift`: canvas, touch-down input, HUD, title, banner, hint, game over and pause.
- The simulator panel's screenshots can lag; verify with `xcrun simctl io <udid> screenshot`.
- Signing: `Config/Base.xcconfig` optionally includes `Config/Local.xcconfig` (git-ignored) for `DEVELOPMENT_TEAM`. Never put a team ID in `project.yml`, the project file or any committed file, and don't set the team in Xcode's Signing tab (it writes into the committed project).
- Real devices and TestFlight: `docs/DEVICES.md`; recipes `just teams`, `just phones`, `just device NAME`, `just archive`, `just testflight`. As of 11 Nov 2026 Xcode had no Apple account signed in and the Developer Program membership was undecided.

## Rules

Every rule and constant is in `docs/RULES.md`. Port them exactly. Saved records (localStorage keys in the web build): `perihelion.hi` (best points), `perihelion.far` (furthest star), `perihelion.muted`.

## Determinism and the replay tests

- `just test` runs the Swift tests; `just fixtures` regenerates `PerihelionKit/Tests/PerihelionCoreTests/Fixtures/*.json` by slicing the rules out of `web/perihelion-2d.html` (by its `/* ===== World` and `/* ===== Effects` markers) and running them in JavaScriptCore.
- Fixtures come from JavaScriptCore on purpose: it uses Apple's libm, like Swift. V8 differs in the last bit of `hypot`, `sin`, `cos`, `atan2` and `exp`, and long runs diverge.
- Any change to `PerihelionCore` must keep every replay passing. A deliberate rule change means changing the web file too and regenerating fixtures.
- The engine eases the camera per tick, not per frame, so the bottom-of-screen death is frame-rate independent. The harness does the same.
- Known web quirk, not yet fixed: the coaching aim line folds at the walls differently from the real flight, so it can be a few units off after a bounce.

## Look, sound and feel (port the intent, not the code)

- **Look:** a cyanotype star chart in Prussian blue, chalk white and a comet gold of `#f4c95d`; red and blue stars are tinted ember `#ff8a66` and ice `#a9dcff`. Fonts are IM Fell English (italic, for display) and DM Mono (for data), both open-licensed Google Fonts that can be bundled in the app. Star labels show name, Bayer designation, spectral class and magnitude, and appear ("ink in") when a star is first charted.
- **On-screen cues:** a dotted aim line along the tangent, folded at the walls. A gold arc on the ring shows the lap still open for flow. The fuse is a ring around the star body that turns ember below 30%.
- **Coaching:** on the first three stars, until the player has reached star 5 in some run, the aim line lights up when it would hit the next star.
- **Game feel:** on each catch, brief slow motion (×0.3 for 0.05 s, or 0.11 s on a dead centre) plus a camera punch. Supernova: shake, flash and particles. Score count-up, pop-up tags, and constellation lines drawn between the stars you caught. Slow motion only changes how fast ticks run in real time, never the rules.
- **Sound** is all synthesised with WebAudio, through a generated reverb:
  - each catch plucks a pentatonic note that climbs with flow (`SCALE` array), with a bell on a dead centre
  - a drone pad opens up as flow builds
  - noise whooshes, wall knocks and fuse ticks
  - **On iOS:** AVAudioEngine can do the same, or swap in sampled sounds.
- **3D version only:**
  - **Scene:** the chart becomes a floating strip with rails, the stars are glowing spheres hovering 40 units above it, and the sky is a starfield.
  - **Camera:** a chase camera at 52° elevation and 62° field of view. It orbits on the title screen, widens and banks in flight, and cranes away on death.
  - **Known trade-off:** foreshortening makes the far side of an orbit harder to judge. Raising the camera elevation is the knob for this.

## Native architecture

1. **Rules** (`PerihelionCore`, done): `Game` is a value type with `tick()` on a fixed 120 Hz step, `act()`, seeded `Mulberry32`, `castAim()`, and `drainEvents()` returning `release`, `capture`, `flowLost`, `knock`, `fuse`, `supernova`, `plate`, `died`. No UIKit, SpriteKit or SwiftUI imports.
2. **Presentation:** a frame clock that accumulates real time (with slow motion) into fixed ticks, plus effects, haptics and sound driven by events. Restarting after death (0.6 s guard) and pausing live here, not in the engine.
3. **Rendering:**
   - **2D:** SpriteKit, or SwiftUI `Canvas` in a `TimelineView`.
   - **3D:** RealityKit or Metal. Apple deprecated SceneKit in 2025; confirm the current guidance before choosing.

Native-only additions worth planning: Core Haptics on catch, dead centre and supernova; a Game Center leaderboard for best points; safe areas and ProMotion at 120 Hz; pause on app backgrounding (the web version already does this).

## Testing on the simulator

The iPhone 17 simulator (iOS 27.0) is set up for this project. If Claude's simulator panel fails with "Failed to initialize simulator device set" after an Xcode component update, restart the simulator services: `killall com.apple.CoreSimulator.CoreSimulatorService; pkill -f claude-ios-sim`, then boot the device again.

## Other files

- `tools/reference.mjs`: the reference harness (JavaScriptCore and V8), writes fixtures and prints where V8 diverges.
- `tools/screenshots.mjs`: README screenshots through the Chrome DevTools protocol.
- `web/playtest/`: Playwright play-tests for the web builds (`play.mjs` for 2D, `play3d.mjs` for 3D). Each page exposes `window.__perihelion` when `window.__TEST__` is set. `just playtest` installs Playwright locally and runs the 2D one with installed Chrome.
