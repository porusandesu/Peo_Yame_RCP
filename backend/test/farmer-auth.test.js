const assert = require("node:assert/strict");
const fs = require("node:fs");
const net = require("node:net");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");
const { once } = require("node:events");
const test = require("node:test");
const { authenticatorCode } = require("../authenticator");

async function unusedPort() {
  const listener = net.createServer();
  listener.listen(0, "127.0.0.1");
  await once(listener, "listening");
  const port = listener.address().port;
  await new Promise((resolve, reject) => listener.close((error) => error ? reject(error) : resolve()));
  return port;
}

async function connectEvents(base) {
  const response = await fetch(`${base}/api/events`);
  assert.equal(response.status, 200);
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  async function nextEvent() {
    while (true) {
      buffer = buffer.replaceAll("\r\n", "\n");
      const separator = buffer.indexOf("\n\n");
      if (separator >= 0) {
        const block = buffer.slice(0, separator);
        buffer = buffer.slice(separator + 2);
        const data = block.split("\n").find((line) => line.startsWith("data:"));
        if (data) return JSON.parse(data.slice(5).trim());
        continue;
      }
      const { done, value } = await reader.read();
      if (done) throw new Error("The realtime update stream closed unexpectedly.");
      buffer += decoder.decode(value, { stream: true });
    }
  }
  return {
    nextEvent,
    nextEventOfType: async (type) => {
      while (true) {
        const event = await nextEvent();
        if (event.type === type) return event;
      }
    },
    close: () => reader.cancel(),
  };
}

async function webSessionSites(base, token) {
  const response = await fetch(`${base}/api/farmer/crops`, {
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(response.status, 200);
  return response.json();
}

test("phone account registration, password login, session restore, logout, and demo independence", { timeout: 30000 }, async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "peo-yame-auth-"));
  const port = await unusedPort();
  const server = spawn(process.execPath, ["server.js"], {
    cwd: path.join(__dirname, ".."),
    env: {
      ...process.env,
      NODE_ENV: "development",
      AUTH_ENABLED: "true",
      PUBLIC_BASE_URL: "",
      HOST: "127.0.0.1",
      PORT: String(port),
      DATABASE_PATH: path.join(directory, "accounts.sqlite"),
      ACTION_LOG_PATH: path.join(directory, "actions.jsonl"),
      APP_DATA_DIR: directory,
      SEED_DEMO_HISTORY: "false",
      NO_BROWSER: "1",
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let output = "";
  server.stdout.on("data", (chunk) => { output += chunk; });
  server.stderr.on("data", (chunk) => { output += chunk; });
  t.after(async () => {
    server.kill();
    if (server.exitCode === null) await Promise.race([once(server, "exit"), new Promise((resolve) => setTimeout(resolve, 2000))]);
    fs.rmSync(directory, { recursive: true, force: true });
  });

  const base = `http://127.0.0.1:${port}`;
  let ready = false;
  for (let attempt = 0; attempt < 60; attempt++) {
    if (server.exitCode !== null) throw new Error(`Backend exited early: ${output}`);
    try {
      const response = await fetch(`${base}/api/health`);
      if (response.ok) { ready = true; break; }
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  assert.ok(ready, `backend became ready: ${output}`);
  const health = await (await fetch(`${base}/api/health`)).json();
  assert.equal(health.demoMode, true);
  assert.equal(health.authEnabled, true);

  const registration = await fetch(`${base}/api/auth/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Demo Farmer Test", phone: "71234567", password: "correct-horse-battery" }),
  });
  assert.equal(registration.status, 201);
  const created = await registration.json();
  assert.equal(created.farmer.phone, "+26771234567");
  assert.equal(created.farmer.email, "");
  assert.ok(created.token);

  const profileUpdate = await fetch(`${base}/api/account`, {
    method: "PATCH",
    headers: { authorization: `Bearer ${created.token}`, "content-type": "application/json" },
    body: JSON.stringify({ name: "Updated Demo Farmer" }),
  });
  assert.equal(profileUpdate.status, 200);
  assert.equal((await profileUpdate.json()).name, "Updated Demo Farmer");

  const demoPage = await (await fetch(base)).text();
  assert.match(demoPage, /id="enterDemoMode"/);
  const missingSession = await fetch(`${base}/api/auth/session`);
  assert.equal(missingSession.status, 401);
  const restoredSession = await fetch(`${base}/api/auth/session`, { headers: { authorization: `Bearer ${created.token}` } });
  assert.equal(restoredSession.status, 200);
  assert.equal((await restoredSession.json()).farmer.id, created.farmer.id);

  // Both app clients subscribe to the same backend snapshot stream.
  const [webEvents, mobileEvents] = await Promise.all([connectEvents(base), connectEvents(base)]);
  const [webConnected, mobileConnected] = await Promise.all([webEvents.nextEvent(), mobileEvents.nextEvent()]);
  assert.ok(webConnected.time);
  assert.ok(mobileConnected.time);
  const accountUpdates = Promise.all([
    webEvents.nextEventOfType("account"),
    mobileEvents.nextEventOfType("account"),
  ]);

  const ownedCrop = await fetch(`${base}/api/farmer/crops`, {
    method: "POST",
    headers: { authorization: `Bearer ${created.token}`, "content-type": "application/json" },
    body: JSON.stringify({ commodity: "Maize", label: "Main store" }),
  });
  assert.equal(ownedCrop.status, 201);
  const site = await ownedCrop.json();
  const accountEvents = await accountUpdates;
  assert.equal(accountEvents[0].updatedAt, accountEvents[1].updatedAt);
  const [webSites, mobileSites] = await Promise.all([webSessionSites(base, created.token), webSessionSites(base, created.token)]);
  assert.deepEqual(webSites, mobileSites);
  const sensorReading = await fetch(`${base}/api/readings`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ temperature: 20, humidity: 50, site: "sensor-001" }),
  });
  assert.equal(sensorReading.status, 201);
  const discovered = await fetch(`${base}/api/farmer/available-sensors`, { headers: { authorization: `Bearer ${created.token}` } });
  assert.ok((await discovered.json()).some((sensor) => sensor.sensorId === "sensor-001"));
  const linked = await fetch(`${base}/api/farmer/sensors`, {
    method: "POST",
    headers: { authorization: `Bearer ${created.token}`, "content-type": "application/json" },
    body: JSON.stringify({ sensorId: "sensor-001", siteId: site.id }),
  });
  assert.equal(linked.status, 201);
  const ownedSensors = await fetch(`${base}/api/farmer/sensors`, { headers: { authorization: `Bearer ${created.token}` } });
  assert.equal((await ownedSensors.json())[0].siteLabel, "Main store");

  const selectionUpdates = Promise.all([
    webEvents.nextEventOfType("selection"),
    mobileEvents.nextEventOfType("selection"),
  ]);
  const selectTomato = await fetch(`${base}/api/commodity`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Tomato", source: "sync-test" }),
  });
  assert.equal(selectTomato.status, 200);
  const selectionEvents = await selectionUpdates;
  assert.equal(selectionEvents[0].updatedAt, selectionEvents[1].updatedAt);
  const [webStatus, mobileStatus] = await Promise.all([
    fetch(`${base}/api/status`).then((response) => response.json()),
    fetch(`${base}/api/status`).then((response) => response.json()),
  ]);
  assert.equal(webStatus.threshold.commodity, "Tomato");
  assert.deepEqual(webStatus, mobileStatus);

  const readingUpdates = Promise.all([
    webEvents.nextEventOfType("reading"),
    mobileEvents.nextEventOfType("reading"),
  ]);
  const breach = await fetch(`${base}/api/sim/breach`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  });
  assert.equal(breach.status, 201);
  const readingEvents = await readingUpdates;
  assert.equal(readingEvents[0].updatedAt, readingEvents[1].updatedAt);
  const [webAlerts, mobileAlerts] = await Promise.all([
    fetch(`${base}/api/alerts`).then((response) => response.json()),
    fetch(`${base}/api/alerts`).then((response) => response.json()),
  ]);
  assert.ok(webAlerts.length > 0);
  assert.deepEqual(webAlerts, mobileAlerts);
  const alertUpdates = Promise.all([
    webEvents.nextEventOfType("alerts"),
    mobileEvents.nextEventOfType("alerts"),
  ]);
  const reviewed = await fetch(`${base}/api/alerts/${webAlerts[0].id}/acknowledge`, { method: "POST" });
  assert.equal(reviewed.status, 200);
  const alertEvents = await alertUpdates;
  assert.equal(alertEvents[0].updatedAt, alertEvents[1].updatedAt);
  const [reviewedByWeb, reviewedByMobile] = await Promise.all([
    fetch(`${base}/api/alerts`).then((response) => response.json()),
    fetch(`${base}/api/alerts`).then((response) => response.json()),
  ]);
  assert.deepEqual(reviewedByWeb, reviewedByMobile);
  assert.equal(reviewedByWeb[0].acknowledged, true);

  const secondRegistration = await fetch(`${base}/api/auth/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Other Farmer", phone: "72123456", password: "another-correct-password" }),
  });
  assert.equal(secondRegistration.status, 201);
  const otherFarmer = await secondRegistration.json();
  const otherSites = await fetch(`${base}/api/farmer/crops`, { headers: { authorization: `Bearer ${otherFarmer.token}` } });
  assert.deepEqual(await otherSites.json(), []);
  const foreignDelete = await fetch(`${base}/api/farmer/crops/${site.id}`, {
    method: "DELETE",
    headers: { authorization: `Bearer ${otherFarmer.token}` },
  });
  assert.equal(foreignDelete.status, 404);
  const unlinkSensor = await fetch(`${base}/api/farmer/sensors/sensor-001`, {
    method: "DELETE",
    headers: { authorization: `Bearer ${created.token}` },
  });
  assert.equal(unlinkSensor.status, 200);
  const deleteOwnSite = await fetch(`${base}/api/farmer/crops/${site.id}`, {
    method: "DELETE",
    headers: { authorization: `Bearer ${created.token}` },
  });
  assert.equal(deleteOwnSite.status, 200);
  assert.deepEqual(await webSessionSites(base, created.token), []);
  const unlinkedAvailable = await fetch(`${base}/api/farmer/available-sensors`, {
    headers: { authorization: `Bearer ${created.token}` },
  });
  assert.ok((await unlinkedAvailable.json()).some((sensor) => sensor.sensorId === "sensor-001"));

  const badLogin = await fetch(`${base}/api/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ phone: "+267 71 234 567", password: "incorrect-password" }),
  });
  assert.equal(badLogin.status, 401);

  const login = await fetch(`${base}/api/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ phone: "+267 71 234 567", password: "correct-horse-battery" }),
  });
  assert.equal(login.status, 200);
  const signedIn = await login.json();
  assert.ok(signedIn.token);

  const setupAuthenticator = await fetch(`${base}/api/account/authenticator/setup`, {
    method: "POST",
    headers: { authorization: `Bearer ${signedIn.token}` },
  });
  assert.equal(setupAuthenticator.status, 200);
  const setup = await setupAuthenticator.json();
  assert.match(setup.otpauthUrl, /^otpauth:\/\/totp\//);
  const enableAuthenticator = await fetch(`${base}/api/account/authenticator/enable`, {
    method: "POST",
    headers: { authorization: `Bearer ${signedIn.token}`, "content-type": "application/json" },
    body: JSON.stringify({ code: authenticatorCode(setup.secret) }),
  });
  assert.equal(enableAuthenticator.status, 200);

  const missingAuthenticator = await fetch(`${base}/api/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ phone: "71234567", password: "correct-horse-battery" }),
  });
  assert.equal(missingAuthenticator.status, 401);
  const code = authenticatorCode(setup.secret);
  const protectedLogin = await fetch(`${base}/api/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ phone: "71234567", password: "correct-horse-battery", authenticatorCode: code }),
  });
  assert.equal(protectedLogin.status, 200);
  const phoneSession = await protectedLogin.json();

  const webChallengeResponse = await fetch(`${base}/api/auth/qr/web-challenge`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ serverBaseUrl: base }),
  });
  assert.equal(webChallengeResponse.status, 201);
  const webChallenge = await webChallengeResponse.json();
  assert.match(webChallenge.qrCode, /^data:image\/png;base64,/);
  assert.equal(webChallenge.serverBaseUrl, base);
  assert.match(webChallenge.qrPayload, /\?server=http%3A%2F%2F127\.0\.0\.1%3A\d+/);
  const approveChallenge = await fetch(`${base}/api/auth/qr/web-challenge/${webChallenge.challenge}/approve`, {
    method: "POST",
    headers: { authorization: `Bearer ${phoneSession.token}` },
  });
  assert.equal(approveChallenge.status, 202);
  const webLogin = await fetch(`${base}/api/auth/qr/web-challenge/${webChallenge.challenge}`);
  assert.equal(webLogin.status, 200);
  const webSession = await webLogin.json();
  assert.equal(webSession.farmer.id, created.farmer.id);
  assert.ok(webSession.token);
  const reusedWebQr = await fetch(`${base}/api/auth/qr/web-challenge/${webChallenge.challenge}`);
  assert.equal(reusedWebQr.status, 410);

  const mobileChallengeResponse = await fetch(`${base}/api/auth/qr/mobile-challenge`, {
    method: "POST",
    headers: { authorization: `Bearer ${webSession.token}`, "content-type": "application/json" },
    body: JSON.stringify({ serverBaseUrl: base }),
  });
  assert.equal(mobileChallengeResponse.status, 201);
  const mobileChallenge = await mobileChallengeResponse.json();
  assert.match(mobileChallenge.qrCode, /^data:image\/png;base64,/);
  assert.equal(mobileChallenge.serverBaseUrl, base);
  const mobileSessionResponse = await fetch(`${base}/api/auth/qr/mobile-exchange`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ challenge: mobileChallenge.challenge }),
  });
  assert.equal(mobileSessionResponse.status, 200);
  assert.equal((await mobileSessionResponse.json()).farmer.id, created.farmer.id);
  const reusedMobileQr = await fetch(`${base}/api/auth/qr/mobile-exchange`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ challenge: mobileChallenge.challenge }),
  });
  assert.equal(reusedMobileQr.status, 410);

  const duplicate = await fetch(`${base}/api/auth/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Second Farmer", phone: "+26771234567", password: "another-long-password" }),
  });
  assert.equal(duplicate.status, 409);

  const logout = await fetch(`${base}/api/auth/logout`, {
    method: "POST",
    headers: { authorization: `Bearer ${signedIn.token}` },
  });
  assert.equal(logout.status, 200);
  const expired = await fetch(`${base}/api/auth/session`, { headers: { authorization: `Bearer ${signedIn.token}` } });
  assert.equal(expired.status, 401);
  await Promise.all([webEvents.close(), mobileEvents.close()]);
});
