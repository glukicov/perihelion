import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, 'docs', 'images');
const chrome = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const sleep = ms => new Promise(r => setTimeout(r, ms));

const shots = [
  { name: '2d-title', page: 'perihelion-2d.html', play: 0 },
  { name: '2d-play', page: 'perihelion-2d.html', play: 7000 },
  { name: '3d-title', page: 'perihelion-3d.html', play: 0 },
  { name: '3d-play', page: 'perihelion-3d.html', play: 7000 },
];

const autoplay = `(() => {
  const api = window.__perihelion;
  api.act();
  setInterval(() => {
    const G = api.state();
    if (G.mode !== 'play' || !G.comet.star) return;
    const a = api.aim();
    if (a && a.star && a.star.i > G.reached && a.star.i <= G.reached + 1) api.act();
  }, 4);
})()`;

const browser = spawn(chrome, [
  '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${mkdtempSync(join(tmpdir(), 'perihelion-chrome-'))}`,
  '--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--hide-scrollbars', '--mute-audio', 'about:blank',
]);
const wsUrl = await new Promise((resolve, reject) => {
  browser.stderr.on('data', d => {
    const m = String(d).match(/DevTools listening on (ws:\/\/\S+)/);
    if (m) resolve(m[1]);
  });
  browser.on('exit', code => reject(new Error(`Chrome exited with ${code}`)));
});

const ws = new WebSocket(wsUrl);
await new Promise(r => ws.addEventListener('open', r, { once: true }));
let nextId = 0;
const pending = new Map();
ws.addEventListener('message', e => {
  const msg = JSON.parse(e.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
  }
});
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
  const id = ++nextId;
  pending.set(id, { resolve, reject });
  ws.send(JSON.stringify({ id, method, params, sessionId }));
});

mkdirSync(outDir, { recursive: true });
for (const shot of shots) {
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  const s = (method, params) => send(method, params, sessionId);
  await s('Page.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
  await s('Page.addScriptToEvaluateOnNewDocument', { source: 'window.__TEST__ = { seed: 20261110, speed: 1 };' });
  await s('Page.navigate', { url: pathToFileURL(join(root, 'web', shot.page)).href });
  await sleep(2500);
  if (shot.play) {
    await s('Runtime.evaluate', { expression: autoplay });
    await sleep(shot.play);
  }
  const { data } = await s('Page.captureScreenshot', { format: 'jpeg', quality: 85 });
  writeFileSync(join(outDir, `${shot.name}.jpg`), Buffer.from(data, 'base64'));
  await send('Target.closeTarget', { targetId });
  console.log(`wrote docs/images/${shot.name}.jpg`);
}
ws.close();
browser.kill();
