import { pathToFileURL } from 'node:url';
import { chromium } from 'playwright';

const page_path = process.argv[2];
const out = process.argv[3];
const seed = Number(process.argv[4] || 20261110);

const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : { channel: 'chrome' });
const ctx = await browser.newContext({ viewport: { width: 390, height: 760 }, deviceScaleFactor: 2, hasTouch: true, isMobile: true });
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', e => errors.push(String(e)));
page.on('console', m => { if (m.type() === 'error' && !/ERR_TUNNEL|Failed to load resource/.test(m.text())) errors.push(m.text()); });
await page.addInitScript(s => { window.__TEST__ = { seed: s, speed: 1 }; }, seed);
await page.goto(pathToFileURL(page_path).href);
await page.waitForTimeout(900);
await page.screenshot({ path: `${out}/1-title.png` });

await page.touchscreen.tap(200, 500);
await page.waitForTimeout(500);

/* Autoplayer: let go whenever the cast says the comet would reach a new star. */
const snap = () => page.evaluate(() => {
  const G = window.__perihelion.state();
  return { mode: G.mode, score: G.score, reached: G.reached, flow: G.flow, plate: G.plate, blots: G.blots.length, stats: G.stats, cause: G.cause, paused: G.paused };
});
await page.evaluate(() => {
  const api = window.__perihelion;
  window.__log = [];
  window.__auto = setInterval(() => {
    const G = api.state();
    if (G.mode !== 'play' || G.paused || !G.comet.star) return;
    const aim = api.aim();
    if (aim && aim.star && aim.star.i > G.reached && aim.star.i <= G.reached + (window.__skip || 1)) api.act();
  }, 3);
});

await page.waitForTimeout(2600);
await page.screenshot({ path: `${out}/2-early.png` });
const early = await snap();

/* Run fast to plate III, then watch at normal speed. */
await page.evaluate(() => { window.__TEST__.speed = 4; });
for (let k = 0; k < 60; k++) {
  const s = await snap();
  if (s.mode === 'dead' || (s.reached >= 17 && s.blots > 0)) break;
  await page.waitForTimeout(300);
}
await page.evaluate(() => { window.__TEST__.speed = 1; });
await page.waitForTimeout(700);
await page.screenshot({ path: `${out}/3-plate3.png` });
const mid = await snap();

/* Pause. */
let paused = { paused: null };
if (mid.mode === 'play') {
  await page.tap('#pause-btn');
  await page.waitForTimeout(450);
  await page.screenshot({ path: `${out}/4-paused.png` });
  paused = await snap();
  await page.tap('#resume');
  await page.waitForTimeout(300);
}

/* Stop steering: the star burns out and the run ends. */
await page.evaluate(() => { clearInterval(window.__auto); window.__TEST__.speed = 3; });
for (let k = 0; k < 60; k++) {
  if ((await snap()).mode === 'dead') break;
  await page.waitForTimeout(250);
}
await page.evaluate(() => { window.__TEST__.speed = 1; });
await page.waitForTimeout(900);
await page.screenshot({ path: `${out}/5-over.png` });
const end = await snap();
const overText = await page.evaluate(() => document.getElementById('over').innerText);

await page.touchscreen.tap(200, 500);
await page.waitForTimeout(400);
const again = await snap();

console.log(JSON.stringify({ early, mid, paused: paused.paused, end, overText, again: { mode: again.mode, score: again.score }, errors }, null, 1));
await browser.close();
