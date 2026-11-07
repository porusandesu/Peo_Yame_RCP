const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const test = require('node:test');

async function unusedPort() {
  const listener = net.createServer();
  listener.listen(0, '127.0.0.1');
  await once(listener, 'listening');
  const port = listener.address().port;
  await new Promise((resolve, reject) => listener.close((error) => error ? reject(error) : resolve()));
  return port;
}

test('backend initializes the starter crop package and serves its guidance', { timeout: 30000 }, async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'peo-yame-crops-'));
  const port = await unusedPort();
  const server = spawn(process.execPath, ['server.js'], {
    cwd: path.join(__dirname, '..'),
    env: {
      ...process.env,
      NODE_ENV: 'development',
      HOST: '127.0.0.1',
      PORT: String(port),
      DATABASE_PATH: path.join(directory, 'crops.sqlite'),
      ACTION_LOG_PATH: path.join(directory, 'actions.jsonl'),
      SEED_DEMO_HISTORY: 'false',
      NO_BROWSER: '1',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let output = '';
  server.stdout.on('data', (chunk) => { output += chunk; });
  server.stderr.on('data', (chunk) => { output += chunk; });
  t.after(async () => {
    server.kill();
    if (server.exitCode === null) await Promise.race([once(server, 'exit'), new Promise((resolve) => setTimeout(resolve, 2000))]);
    fs.rmSync(directory, { recursive: true, force: true });
  });

  const base = `http://127.0.0.1:${port}`;
  let health;
  for (let attempt = 0; attempt < 60; attempt++) {
    if (server.exitCode !== null) throw new Error(`Backend exited early: ${output}`);
    try {
      health = await fetch(`${base}/api/health`);
      break;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  }
  assert.ok(health, `backend became ready: ${output}`);
  assert.equal(health.status, 200);
  assert.equal((await health.json()).demoMode, true);

  const response = await fetch(`${base}/api/crops`);
  assert.equal(response.status, 200);
  const crops = await response.json();
  assert.ok(crops.length >= 24, 'starter profiles are present');
  for (const group of ['Grain', 'Pulse', 'Oilseed', 'Vegetable', 'Fruit']) {
    assert.ok(crops.some((crop) => crop.cropGroup === group), `${group} profiles are present`);
  }
  const maize = crops.find((crop) => crop.commodity === 'Maize');
  assert.equal(maize.safeMoisturePct, 13.5);
  assert.match(maize.storageNote, /grain moisture meter/i);
  const tomato = crops.find((crop) => crop.commodity === 'Tomato');
  assert.equal(tomato.cropGroup, 'Vegetable');
  assert.match(tomato.storageNote, /chilling/i);
});
