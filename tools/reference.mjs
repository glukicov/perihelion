import { readFileSync, writeFileSync, mkdirSync, mkdtempSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const html = readFileSync(join(root, 'web', 'perihelion-2d.html'), 'utf8');
const outDir = join(root, 'PerihelionKit', 'Tests', 'PerihelionCoreTests', 'Fixtures');
const JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc';

function slice(from, to) {
  const a = html.indexOf(from);
  const b = html.indexOf(to, a);
  if (a < 0 || b < 0) throw new Error(`marker not found: ${from} .. ${to}`);
  return html.slice(a, b);
}

const rules = [
  slice('const W = 400;', '/* ================= Plumbing'),
  slice('const clamp = ', '/* ================= Sound'),
  slice('/* ================= World', '/* ================= Effects'),
].join('\n');

export const scenarios = [
  { name: 'steady', seed: 20261110, mode: 'play', skip: 1, eager: 1, wild: 0 },
  { name: 'greedy', seed: 7, mode: 'play', skip: 3, eager: 0.5, wild: 0, policySeed: 3 },
  { name: 'hesitant', seed: 314159, mode: 'play', skip: 1, eager: 0.03, wild: 0, policySeed: 5 },
  { name: 'wild', seed: 42, mode: 'play', skip: 3, eager: 0.7, wild: 0.0006, policySeed: 11 },
  { name: 'title-then-burnout', seed: 99, mode: 'title', startAt: 90, skip: 1, eager: 1, wild: 0, stopAt: 12 },
  { name: 'deep', seed: 2718, mode: 'play', skip: 2, eager: 0.3, wild: 0, policySeed: 17 },
  { name: 'reckless', seed: 1234567, mode: 'play', skip: 2, eager: 0.9, wild: 0.002, policySeed: 23 },
  { name: 'horsehead', seed: 46, mode: 'play', skip: 3, eager: 0.85, wild: 0.004, policySeed: 322 },
  { name: 'snake', seed: 72, mode: 'play', skip: 3, eager: 0.85, wild: 0.004, policySeed: 504 },
];

const driver = String.raw`
'use strict';
const VIEW_HEIGHT = 780;
const MAX_TICKS = 120 * 300;
const CHECKPOINT = 240;
const round = v => (Number.isFinite(v) ? Math.round(v * 1e6) / 1e6 : v);

function makeGame(SEED, record) {
  const el = () => ({ classList: { add() {}, remove() {} }, style: {}, dataset: {} });
  const $ = el;
  const document = { body: { style: {}, dataset: {} } };
  const Snd = { mood() {} };
  const C = { chalk: '#fff', comet: '#f4c95d', ember: '#ff8a66', ice: '#a9dcff' };
  const TEST = { seed: SEED };
  const V = { vh: VIEW_HEIGHT };
  const rec = { hi: 0, far: 0 };
  let G = null;
  function paintHud() {}
  function openingHint() {}
  function emit(type, d) {
    record(type, d, G);
    if (type === 'die') G.mode = 'dead';
  }
  /*RULES*/
  return {
    newGame, act, tick, castAim, ensureStars, STEP,
    state: () => G,
    camera(dt) { G.camY += (G.camT - G.camY) * (1 - Math.exp(-dt * 4.5)); }
  };
}

function mulberry(a) {
  return () => {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function predict(G, STEP) {
  const c = G.comet;
  const speed = 460 + Math.min(G.reached, 40) * 4;
  let vx = -Math.sin(c.ang) * c.dir * speed;
  let vy = Math.cos(c.ang) * c.dir * speed;
  let x = c.x, y = c.y, flown = 0, t = G.t, from = c.star;
  const sx = s => (s.amp ? s.x0 + s.amp * Math.sin(s.ph + t * s.spd) : s.x);
  for (;;) {
    t += STEP;
    flown += Math.hypot(vx, vy) * STEP;
    x += vx * STEP;
    y += vy * STEP;
    if (x < 6) { x = 6; vx = Math.abs(vx); } else if (x > 394) { x = 394; vx = -Math.abs(vx); }
    if (from && Math.hypot(x - sx(from), y - from.y) > from.R + 12) from = null;
    for (const b of G.blots) if (Math.hypot(x - b.x, y - b.y) < b.r) return null;
    for (const s of G.stars) {
      if (s.dead || s === from) continue;
      if (Math.hypot(x - sx(s), y - s.y) < s.R + 5) return s;
    }
    if (flown > 540) return null;
  }
}

function aimOf(game) {
  const a = game.castAim();
  if (!a) return null;
  return a.star ? { star: a.star.i, d: a.d } : { nebula: game.state().blots.indexOf(a.blot), d: a.d };
}

function run(scenario) {
  const events = [];
  const checkpoints = [];
  let tickNow = 0;
  const record = (type, d, G) => {
    const c = G.comet;
    const e = { tick: tickNow, type, x: round(c.x), y: round(c.y) };
    if (type === 'release') e.auto = d.auto;
    if (type === 'capture') Object.assign(e, { star: d.s.i, isNew: d.isNew, points: d.pts, tags: d.tags, centre: d.centre, lost: d.lost });
    if (type === 'fuse') e.left = round(d.left);
    if (type === 'supernova') e.star = d.s.i;
    if (type === 'plate') e.plate = d.plate;
    if (type === 'die') { e.kind = d.kind; e.cause = G.cause; }
    events.push(e);
  };
  const game = makeGame(scenario.seed, record);
  game.newGame(scenario.mode);
  const G = game.state;
  const policy = mulberry(scenario.policySeed || 1);
  const taps = [];

  for (tickNow = 0; tickNow < MAX_TICKS; tickNow++) {
    const g = G();
    if (g.mode === 'dead') break;
    let tap = false;
    if (g.mode === 'title') tap = tickNow === scenario.startAt;
    else if (g.comet.star && g.reached < (scenario.stopAt || Infinity)) {
      const hit = predict(g, game.STEP);
      const good = hit && hit.i > g.reached && hit.i <= g.reached + scenario.skip;
      if (good && policy() < scenario.eager) tap = true;
      else if (policy() < scenario.wild) tap = true;
    }
    if (tap) { taps.push(tickNow); game.act(); }
    game.tick(game.STEP);
    game.camera(game.STEP);
    game.ensureStars();
    if (tickNow % CHECKPOINT === 0) {
      const s = G();
      checkpoints.push({
        tick: tickNow, x: round(s.comet.x), y: round(s.comet.y), camY: round(s.camY),
        score: s.score, reached: s.reached, flow: s.flow, stars: s.stars.length, nebulae: s.blots.length,
        firstStar: s.stars[0].i, aim: aimOf(game)
      });
    }
  }
  const g = G();
  return {
    name: scenario.name, seed: scenario.seed, mode: scenario.mode, viewHeight: VIEW_HEIGHT,
    ticks: tickNow, taps, events, checkpoints,
    final: { mode: g.mode, score: g.score, reached: g.reached, flow: g.flow, plate: g.plate, cause: g.cause, stats: g.stats }
  };
}

const out = typeof print === 'function' ? print : console.log;
out(JSON.stringify(SCENARIOS.map(run)));
`;

function runIn(engine, file) {
  const cmd = engine === 'jsc' ? JSC : process.execPath;
  return JSON.parse(execFileSync(cmd, [file], { maxBuffer: 1 << 30, encoding: 'utf8' }));
}

function firstDivergence(a, b) {
  const n = Math.min(a.events.length, b.events.length);
  for (let k = 0; k < n; k++) {
    if (JSON.stringify(a.events[k]) !== JSON.stringify(b.events[k])) return a.events[k].tick;
  }
  return a.events.length === b.events.length ? null : a.events[n]?.tick ?? b.events[n]?.tick;
}

const work = mkdtempSync(join(tmpdir(), 'perihelion-'));
const bundle = join(work, 'bundle.js');
writeFileSync(bundle, driver.replace('/*RULES*/', rules).replace('SCENARIOS', JSON.stringify(scenarios)));

const safari = runIn('jsc', bundle);
const chrome = runIn('node', bundle);

mkdirSync(outDir, { recursive: true });
for (const r of safari) writeFileSync(join(outDir, `${r.name}.json`), JSON.stringify(r) + '\n');

const rows = safari.map((r, k) => {
  const v = chrome[k];
  const kinds = {};
  for (const e of r.events) kinds[e.type] = (kinds[e.type] || 0) + 1;
  return {
    name: r.name, ticks: r.ticks, score: r.final.score, reached: r.final.reached, cause: r.final.cause,
    v8Score: v.final.score, v8DivergesAt: firstDivergence(r, v), events: kinds
  };
});
console.log(JSON.stringify(rows, null, 1));
