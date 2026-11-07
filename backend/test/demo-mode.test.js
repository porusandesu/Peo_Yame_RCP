const assert = require("node:assert/strict");
const { execFileSync, spawn } = require("node:child_process");
const fs = require("node:fs");
const net = require("node:net");
const os = require("node:os");
const path = require("node:path");
const { once } = require("node:events");
const test = require("node:test");

async function freePort() {
  const server = net.createServer();
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const { port } = server.address();
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  return port;
}

test("demo mode opens farmer/crop APIs without auth and disables sign-in", { timeout: 30000 }, async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "peo-yame-demo-"));
  const port = await freePort();
  const sqlitePath = process.env.SQLITE3_PATH || (process.platform === "win32"
    ? path.join(__dirname, "..", "vendor", "sqlite3.exe")
    : "sqlite3");
  const databasePath = path.join(directory, "demo.sqlite");
  execFileSync(sqlitePath, [databasePath], {
    input: `CREATE TABLE crops (
      id INTEGER PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      min_temp REAL NOT NULL, max_temp REAL NOT NULL,
      min_humidity REAL NOT NULL, max_humidity REAL NOT NULL,
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
    );
    INSERT INTO crops(name,min_temp,max_temp,min_humidity,max_humidity)
    VALUES('Maize',10,27,30,70);`,
    encoding: "utf8",
  });
  const server = spawn(process.execPath, ["server.js"], {
    cwd: path.join(__dirname, ".."),
    env: {
      ...process.env,
      NODE_ENV: "development",
      HOST: "127.0.0.1",
      PORT: String(port),
      DATABASE_PATH: databasePath,
      APP_DATA_DIR: directory,
      SQLITE3_PATH: sqlitePath,
      NO_BROWSER: "1",
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let serverOutput = "";
  server.stdout.on("data", (chunk) => { serverOutput += chunk; });
  server.stderr.on("data", (chunk) => { serverOutput += chunk; });
  t.after(async () => {
    server.kill();
    if (server.exitCode === null) await Promise.race([once(server, "exit"), new Promise((resolve) => setTimeout(resolve, 2000))]);
    fs.rmSync(directory, { recursive: true, force: true });
  });

  const baseUrl = `http://127.0.0.1:${port}`;
  let health;
  for (let attempt = 0; attempt < 60; attempt++) {
    if (server.exitCode !== null) throw new Error(`Demo backend exited with code ${server.exitCode}: ${serverOutput}`);
    try {
      health = await fetch(`${baseUrl}/api/health`);
      break;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  }
  assert.ok(health, `backend became ready: ${serverOutput}`);
  assert.equal(health.status, 200);
  assert.equal((await health.json()).demoMode, true);

  const accountResponse = await fetch(`${baseUrl}/api/account`);
  assert.equal(accountResponse.status, 200);
  assert.equal((await accountResponse.json()).name, "Demo Farmer");

  const cropResponse = await fetch(`${baseUrl}/api/crops`);
  assert.equal(cropResponse.status, 200);
  const crops = await cropResponse.json();
  assert.ok(crops.length >= 20, "starter crop catalog is seeded");
  const maize = crops.find((crop) => crop.commodity === "Maize");
  assert.equal(maize.cropGroup, "Grain", "existing crop rows are migrated");
  assert.equal(maize.safeMoisturePct, 13);
  for (const group of ["Grain", "Pulse", "Oilseed", "Vegetable", "Fruit"]) {
    assert.ok(crops.some((crop) => crop.cropGroup === group), `${group} profiles are seeded`);
  }

  const addCrop = await fetch(`${baseUrl}/api/farmer/crops`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ commodity: "Maize", label: "Smoke-test store" }),
  });
  assert.equal(addCrop.status, 201);
  const savedCrop = await addCrop.json();
  const farmerCrops = await fetch(`${baseUrl}/api/farmer/crops`);
  assert.equal(farmerCrops.status, 200);
  assert.ok((await farmerCrops.json()).some((crop) => crop.id === savedCrop.id));
  const removeCrop = await fetch(`${baseUrl}/api/farmer/crops/${savedCrop.id}`, { method: "DELETE" });
  assert.equal(removeCrop.status, 200);

  for (const [route, body] of [
    ["/api/auth/request-otp", { phone: "+26771234567" }],
    ["/api/auth/verify-otp", { phone: "+26771234567", code: "123456" }],
    ["/api/auth/demo/skip-verification", { phone: "+26771234567" }],
    ["/api/auth/password", { email: "demo@example.com", password: "password" }],
    ["/api/auth/mobile-qr", { challenge: "unused" }],
    ["/api/auth/web-login-qr", {}],
    ["/api/account/authenticator/setup", {}],
  ]) {
    const response = await fetch(`${baseUrl}${route}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    assert.equal(response.status, 404, `${route} is unavailable in demo mode`);
  }
});
