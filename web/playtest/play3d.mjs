import { pathToFileURL } from 'node:url';
import { readFileSync } from 'node:fs';
import { chromium } from 'playwright';

const [page_path, out, seedArg, widthArg, heightArg] = process.argv.slice(2);
const seed = Number(seedArg || 20261110);
const three = process.env.THREE_JS ? readFileSync(process.env.THREE_JS, 'utf8') : null;

const browser = await chromium.launch({
  ...(process.env.CHROME ? { executablePath: process.env.CHROME } : { channel: 'chrome' }),
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl']
});
const ctx = await browser.newContext({
  viewport: { width: Number(widthArg || 390), height: Number(heightArg || 760) }, deviceScaleFactor: 2, hasTouch: true, isMobile: true
});
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', e => errors.push(String(e)));
page.on('console', m => {
  const t = m.text();
  if ((m.type() === 'error' || m.type() === 'warning') && !/ERR_TUNNEL|Failed to load resource|GPU stall|Automatic fallback to software/.test(t)) errors.push(m.type() + ': ' + t);
});
/* The sandbox cannot reach the CDN, so hand the page the same library from disk. */
if (three) await page.route('**/three.min.js', route => route.fulfill({ contentType: 'application/javascript', body: three }));
await page.addInitScript(s => { window.__TEST__ = { seed: s, speed: 1 }; }, seed);
await page.goto(pathToFileURL(page_path).href);
await page.waitForTimeout(1500);

const snap = () => page.evaluate(() => {
  const G = window.__perihelion && window.__perihelion.state();
  if (!G) return { mode: document.body.dataset.mode };
  return { mode: G.mode, score: G.score, reached: G.reached, flow: G.flow, plate: G.plate, blots: G.blots.length, cause: G.cause, paused: G.paused, clock: +G.clock.toFixed(2) };
});
const t0 = await snap();
await page.screenshot({ path: `${out}/3d-1-title.png` });
if (t0.mode !== 'title') { console.log(JSON.stringify({ t0, errors }, null, 1)); await browser.close(); process.exit(0); }

await page.touchscreen.tap(200, 500);
/* Software rendering is slow, so wait on game time, not wall time. */
const waitClock = async (sec) => { const a = (await snap()).clock; for (let k = 0; k < 400; k++) { if ((await snap()).clock - a >= sec) return; await page.waitForTimeout(100); } };
await waitClock(2.2);
await page.screenshot({ path: `${out}/3d-2-start.png` });

await page.evaluate(() => {
  const api = window.__perihelion;
  window.__auto = setInterval(() => {
    const G = api.state();
    if (G.mode !== 'play' || G.paused || !G.comet.star) return;
    const aim = api.aim();
    if (aim && aim.star && aim.star.i === G.reached + 1) api.act();
  }, 3);
});
await waitClock(4.5);
await page.screenshot({ path: `${out}/3d-3-early.png` });
const early = await snap();

/* Freeze mid-flight for a look at the camera in motion. */
await page.evaluate(() => new Promise(done => {
  const api = window.__perihelion;
  const id = setInterval(() => { const G = api.state(); if (G.mode !== 'play' || (!G.comet.star && G.comet.flown > 90)) { window.__TEST__.speed = 0.00001; clearInterval(id); done(); } }, 2);
}));
await page.waitForTimeout(400);
await page.screenshot({ path: `${out}/3d-4-flight.png` });

/* Run fast until a nebula is close, then look. */
await page.evaluate(() => new Promise(done => {
  const api = window.__perihelion;
  window.__TEST__.speed = 5;
  const id = setInterval(() => {
    const G = api.state(), c = G.comet;
    const near = G.blots.some(b => b.y < G.camY + 60 && b.y > G.camY - 420);
    if (G.mode !== 'play' || (c.star && near && c.lapOpen && c.swept > 0.6 && c.swept < 2.4)) { window.__TEST__.speed = 0.00001; clearInterval(id); done(); }
  }, 2);
}));
await page.waitForTimeout(500);
await page.screenshot({ path: `${out}/3d-5-nebula.png` });
const mid = await snap();

/* Stop steering and let the star burn out. */
await page.evaluate(() => { clearInterval(window.__auto); window.__TEST__.speed = 3; });
for (let k = 0; k < 200; k++) { if ((await snap()).mode === 'dead') break; await page.waitForTimeout(150); }
await page.evaluate(() => { window.__TEST__.speed = 1; });
await waitClock(1.6);
await page.screenshot({ path: `${out}/3d-6-over.png` });
const end = await snap();

await page.touchscreen.tap(200, 500);
await page.waitForTimeout(600);
const again = await snap();
console.log(JSON.stringify({ t0, early, mid, end, again: { mode: again.mode, score: again.score }, errors }, null, 1));
await browser.close();
