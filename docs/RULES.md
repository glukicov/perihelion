# Perihelion rules

The web file [`web/perihelion-2d.html`](../web/perihelion-2d.html) is the reference. When this page and the code
disagree, the code wins, and the replay tests in `PerihelionKit` check that the Swift engine agrees with it.

## The game in one paragraph

A comet orbits a star. Tap to let go and the comet flies off along the tangent. Touch another star's ring and it
catches you. Stars arrive in order of real apparent brightness, from Sol and Sirius down to Hamal, and every star
except Sol burns out on a fuse. Each star is a little harder than the last: smaller ring, faster spin, shorter fuse.
The chart has side walls the comet bounces off. The run ends when the comet flies too far without a catch, drops off
the bottom of the screen, or hits a dark nebula. Score is points, not distance.

## Units and constants

Distances are chart units: the chart is 400 wide and `y` decreases going up the screen. Time is in seconds.

| Constant | Value | Meaning |
|---|---|---|
| `W` | 400 | chart width |
| `ANCHOR` | 0.62 | the star you circle sits this far down the screen |
| `WALL` | 6 | the comet bounces this far inside each edge |
| `RANGE` | 540 | flight distance before the comet is lost |
| `STEP` | 1/120 | fixed simulation step; rendering is separate |
| `CATCH` | 5 | a ring catches at radius `R + CATCH` |
| `PER_PLATE` | 8 | stars per plate (difficulty tier) |
| `MAX_FLOW` | 7 | flow multiplier caps at ×8 |
| `LAP_GRACE` | 0.35 s | leeway past one full lap before flow is lost |
| `CENTRE` | 0.22 | miss distance / (R + CATCH) below this is a dead centre |

## Stars

For star index `i` with kind multipliers `k`:

- **Kind** comes from the real spectral class: O and B are `blue`, K and M are `red`, everything else is `white`,
  and Sol is `sol`. Past the 48-star catalogue, stars are "Uncharted N" with a random kind (25% red, 35% blue).
- **Multipliers:** red is R ×1.3, spin ×0.8, fuse ×0.6. Blue is R ×0.84, spin ×1.18.
- **Ring radius** `R = 62` for Sol, otherwise `max(40, 60 − 0.45i) × k.R`.
- **Spin** `w = (2.3 + 0.026·min(i, 40)) × k.w` rad/s.
- **Gap ahead** `max(175 + 1.2·min(i, 30) + rand·50, prevR + R + 62)`. `x` stays 36 to 190 units sideways from the
  previous star, with 14 tries.
- **Fuse** `max(max(3.2, 7.5 − 0.1i) × k.fuse, 1.7 laps)`, so there is always a fair chance to leave. Sol's fuse is
  infinite.
- **Drift** (plate II on, `i > 8`): probability 0.4, 0.5 or 0.65 for `i ≤ 16`, `≤ 24` or beyond. Amplitude 18 to 45,
  clamped to the walls; speed 0.7 to 1.3 rad/s, ×1.25 past star 24.

## Dark nebulae

From plate III (`i > 16`), with probability 0.45 (`i ≤ 24`) or 0.6. Each is a circle of radius 11 to 15, placed 42 to
74 units to the side of the straight path between two consecutive stars, 42 to 58% of the way along, never
overlapping either star's swept ring. Touching one ends the run.

## Flight, capture and scoring

- **Release:** speed `460 + 4·min(reached, 40)` along the tangent `(−sin a·dir, cos a·dir)`.
- **Capture:** orbit direction from the sign of the cross product; orbit radius eases from the contact distance back
  to `R`.
- **Scoring** happens only on a *new* star (index above the furthest reached), with `n = i − reached` and
  `m = 1 + flow`:
  - base `10·n·m`
  - skip bonus `+25·m` if `n ≥ 2`
  - bank shot `+15·m` if the comet bounced off a wall in flight
  - dead centre `+10·m` if the miss is under `CENTRE`
- **Flow:** +1 when the comet left the previous star during its first lap (`swept < 2π + w·LAP_GRACE`) and catches a
  new star. Flow drops to 0 when a lap completes without letting go, or when an old star recaptures the comet.
- **Burn-out:** when the fuse hits 0 the star goes supernova and flings the comet out.
- **Plates:** a new plate every 8 stars, with a banner, a palette shift and new rules (II drift, III nebulae, IV faster
  drift and more nebulae, V and VI fainter and faster).

## Events

The rules talk to everything else through events: `release`, `capture`, `flowlost`, `knock`, `fuse`, `supernova`,
`plate` and `die`. Sound, haptics, particles and the HUD listen; none of them can change the outcome.
