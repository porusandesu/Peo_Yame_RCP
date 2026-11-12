import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { openDatabase } from "../src/database.js";

async function startBackend(t, { lanHost = "" } = {}) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "peo-yame-parity-"));
  const port = 35000 + Math.floor(Math.random() * 10000);
  const key = crypto.randomBytes(32).toString("hex");
  const env = {
    ...process.env,
    HOST: "127.0.0.1",
    PORT: String(port),
    PEO_YAME_DATA_DIR: directory,
    PEO_YAME_DB_KEY: key,
    PEO_YAME_DEMO_ENABLED: "true",
    PEO_YAME_LAN_HOST: lanHost,
  };
  let child = spawn(process.execPath, ["src/server.js"], { cwd: new URL("..", import.meta.url), env, stdio: "ignore" });
  const base = `http://127.0.0.1:${port}/api`;
  async function waitUntilReady() {
    for (let attempt = 0; attempt < 60; attempt++) {
      if (child.exitCode !== null) throw new Error("Backend exited before becoming ready.");
      try {
        if ((await fetch(`${base}/health`)).ok) return;
      } catch {}
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
    throw new Error("Backend did not become ready.");
  }
  t.after(async () => {
    if (child.exitCode === null && child.signalCode === null) child.kill("SIGTERM");
    if (child.exitCode === null && child.signalCode === null) {
      await new Promise((resolve) => {
        const timer = setTimeout(resolve, 3000);
        child.once("exit", () => { clearTimeout(timer); resolve(); });
      });
    }
    fs.rmSync(directory, { recursive: true, force: true });
  });
  await waitUntilReady();
  return {
    base,
    directory,
    key,
    async restart() {
      if (child.exitCode === null && child.signalCode === null) {
        child.kill("SIGTERM");
        await new Promise((resolve) => child.once("exit", resolve));
      }
      child = spawn(process.execPath, ["src/server.js"], { cwd: new URL("..", import.meta.url), env, stdio: "ignore" });
      await waitUntilReady();
    },
  };
}

async function readUntil(reader, marker) {
  let text = "";
  const deadline = Date.now() + 5000;
  while (!text.includes(marker) && Date.now() < deadline) {
    const result = await reader.read();
    if (result.done) break;
    text += new TextDecoder().decode(result.value);
  }
  assert.ok(text.includes(marker), `Expected event stream to contain ${marker}.`);
  return text;
}

function currentTotp(secret) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = 0;
  let value = 0;
  const bytes = [];
  for (const character of secret) {
    value = (value << 5) | alphabet.indexOf(character);
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  const counter = Math.floor(Date.now() / 30000);
  const buffer = Buffer.alloc(8);
  buffer.writeUInt32BE(Math.floor(counter / 2 ** 32), 0);
  buffer.writeUInt32BE(counter >>> 0, 4);
  const digest = crypto.createHmac("sha1", Buffer.from(bytes)).update(buffer).digest();
  const offset = digest[19] & 15;
  const code = (((digest[offset] & 127) << 24) |
    ((digest[offset + 1] & 255) << 16) |
    ((digest[offset + 2] & 255) << 8) |
    (digest[offset + 3] & 255)) % 1000000;
  return String(code).padStart(6, "0");
}

test("catalog is complete, custom crops are private, and selections persist and stream", async (t) => {
  const { base, restart } = await startBackend(t);
  const first = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "First Farmer", phone: "71234567", password: "parity-test-password" }),
  });
  assert.equal(first.status, 201);
  const firstAccount = await first.json();
  const firstAuth = { authorization: `Bearer ${firstAccount.token}` };

  const builtIns = await fetch(`${base}/crops`).then((response) => response.json());
  assert.equal(builtIns.length, 30);
  for (const category of ["crop", "fruit", "vegetable"]) {
    assert.equal(builtIns.filter((item) => item.category === category).length, 10);
  }

  const streamAbort = new AbortController();
  t.after(() => streamAbort.abort());
  const stream = await fetch(`${base}/events`, { headers: firstAuth, signal: streamAbort.signal });
  assert.equal(stream.status, 200);
  const reader = stream.body.getReader();
  await readUntil(reader, "event: connected");
  assert.equal((await fetch(`${base}/crop-selection`, {
    method: "POST",
    headers: { ...firstAuth, "content-type": "application/json" },
    body: JSON.stringify({ crop: "Maize" }),
  })).status, 200);
  await readUntil(reader, "event: crop");

  const custom = await fetch(`${base}/crops`, {
    method: "POST",
    headers: { ...firstAuth, "content-type": "application/json" },
    body: JSON.stringify({
      name: "Test Melon",
      category: "fruit",
      temperatureMin: 8,
      temperatureMax: 12,
      humidityMin: 80,
      humidityMax: 90,
      baselineWeeks: 2,
    }),
  });
  assert.equal(custom.status, 201);
  const other = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Second Farmer", phone: "72345678", password: "other-parity-password" }),
  });
  assert.equal(other.status, 201);
  const otherAccount = await other.json();
  const otherAuth = { authorization: `Bearer ${otherAccount.token}` };
  const otherCatalog = await fetch(`${base}/crops`, { headers: otherAuth }).then((response) => response.json());
  assert.equal(otherCatalog.length, 30);
  assert.equal(otherCatalog.some((item) => item.name === "Test Melon"), false);
  assert.equal((await fetch(`${base}/sites`, {
    method: "POST",
    headers: { ...otherAuth, "content-type": "application/json" },
    body: JSON.stringify({ name: "Private crop", crop: "Test Melon" }),
  })).status, 400);

  assert.equal((await fetch(`${base}/crop-selection`, {
    method: "POST",
    headers: { ...firstAuth, "content-type": "application/json" },
    body: JSON.stringify({ crop: "Test Melon" }),
  })).status, 200);
  const status = await fetch(`${base}/status`, { headers: firstAuth }).then((response) => response.json());
  assert.equal(status.crop, "Test Melon");
  assert.deepEqual(status.targetBands.temperatureC, [8, 12]);
  assert.equal((await fetch(`${base}/sites`, {
    method: "POST",
    headers: { ...firstAuth, "content-type": "application/json" },
    body: JSON.stringify({ name: "Melon store", crop: "Test Melon" }),
  })).status, 201);
  streamAbort.abort();
  await restart();
  const afterRestart = await fetch(`${base}/status`, { headers: firstAuth }).then((response) => response.json());
  assert.equal(afterRestart.crop, "Test Melon");
  assert.equal((await fetch(`${base}/crops`, { headers: firstAuth }).then((response) => response.json())).some((item) => item.name === "Test Melon"), true);
});

test("phone pairing creation requires an enabled authenticator code", async (t) => {
  const { base } = await startBackend(t);
  const response = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Authenticator Farmer", phone: "74567890", password: "authenticator-password" }),
  });
  const account = await response.json();
  const auth = { authorization: `Bearer ${account.token}`, "content-type": "application/json" };
  assert.equal((await fetch(`${base}/authenticator/setup`, { method: "POST", headers: auth })).status, 401);
  assert.equal((await fetch(`${base}/authenticator/setup`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: "wrong-password" }),
  })).status, 401);
  const setupResponse = await fetch(`${base}/authenticator/setup`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: "authenticator-password" }),
  });
  assert.equal(setupResponse.status, 200);
  const setup = await setupResponse.json();
  assert.equal((await fetch(`${base}/authenticator/enable`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ code: currentTotp(setup.secret) }),
  })).status, 200);
  assert.equal((await fetch(`${base}/authenticator/setup`, { method: "POST", headers: auth })).status, 409);

  const missingCode = await fetch(`${base}/qr/phone/create`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: "authenticator-password" }),
  });
  assert.equal(missingCode.status, 403);
  assert.equal((await missingCode.json()).totpRequired, true);

  const accepted = await fetch(`${base}/qr/phone/create`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: "authenticator-password", totpCode: currentTotp(setup.secret) }),
  });
  assert.equal(accepted.status, 200);
});

test("rejects foreign web origins and requires CSRF proof for cookie-authenticated changes", async (t) => {
  const { base, directory, key } = await startBackend(t);
  const foreign = await fetch(`${base}/health`, { headers: { origin: "https://attacker.example" } });
  assert.equal(foreign.status, 403);
  const preflight = await fetch(`${base}/sites`, {
    method: "OPTIONS",
    headers: { origin: "https://attacker.example", "access-control-request-method": "POST" },
  });
  assert.equal(preflight.status, 403);

  const origin = new URL(base).origin;
  const registered = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { origin, "content-type": "application/json" },
    body: JSON.stringify({ name: "Cookie Farmer", phone: "75678901", password: "cookie-test-password" }),
  });
  assert.equal(registered.status, 201);
  assert.equal(registered.headers.get("access-control-allow-origin"), origin);
  assert.equal((await registered.json()).token, undefined);
  const cookies = registered.headers.getSetCookie();
  const sessionCookie = cookies.find((cookie) => cookie.startsWith("py_session="))?.split(";")[0];
  const csrfCookie = cookies.find((cookie) => cookie.startsWith("py_csrf="))?.split(";")[0];
  assert.ok(sessionCookie);
  assert.ok(csrfCookie);
  assert.match(cookies.find((cookie) => cookie.startsWith("py_session=")), /HttpOnly/i);

  const body = JSON.stringify({ name: "Cookie store", crop: "Maize" });
  const headers = { origin, cookie: `${sessionCookie}; ${csrfCookie}`, "content-type": "application/json" };
  assert.equal((await fetch(`${base}/sites`, { method: "POST", headers, body })).status, 403);
  assert.equal((await fetch(`${base}/sites`, {
    method: "POST",
    headers: { origin, cookie: sessionCookie, "content-type": "application/json" },
    body,
  })).status, 403);
  const csrf = csrfCookie.slice("py_csrf=".length);
  const login = await fetch(`${base}/account/login`, {
    method: "POST",
    headers: { cookie: sessionCookie, "content-type": "application/json" },
    body: JSON.stringify({ phone: "75678901", password: "cookie-test-password" }),
  });
  assert.equal(login.status, 200);
  const created = await fetch(`${base}/sites`, {
    method: "POST",
    headers: { ...headers, "x-csrf-token": csrf },
    body,
  });
  assert.equal(created.status, 201);
  assert.equal((await fetch(`${base}/account`, { headers: { cookie: sessionCookie } })).status, 200);

  const sessionToken = sessionCookie.slice("py_session=".length);
  const encrypted = openDatabase(path.join(directory, "peo-yame.sqlite"), key);
  const tokenHash = crypto.createHash("sha256").update(sessionToken).digest("hex");
  assert.equal(encrypted.prepare("SELECT idle_timeout_minutes FROM sessions WHERE token_hash=?").get(tokenHash).idle_timeout_minutes, 30);
  encrypted.prepare("UPDATE sessions SET last_seen_at=? WHERE token_hash=?").run(
    new Date(Date.now() - 31 * 60000).toISOString(),
    tokenHash,
  );
  encrypted.close();
  assert.equal((await fetch(`${base}/account`, { headers: { cookie: sessionCookie } })).status, 401);
});

test("phone QR sessions expire after 30 minutes idle", async (t) => {
  const { base, directory, key } = await startBackend(t);
  const account = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Idle Farmer", phone: "75678902", password: "idle-test-password" }),
  }).then((response) => response.json());
  const auth = { authorization: `Bearer ${account.token}`, "content-type": "application/json" };
  const pairing = await fetch(`${base}/qr/phone/create`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: "idle-test-password" }),
  }).then((response) => response.json());
  const verifier = "phone-idle-test-verifier";
  const verifierHash = crypto.createHash("sha256").update(verifier).digest("hex");
  const claim = await fetch(`${base}/qr/phone/claim`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ codeId: pairing.codeId, verifierHash, name: "Test phone" }),
  }).then((response) => response.json());
  assert.equal((await fetch(`${base}/qr/phone/approve`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ codeId: pairing.codeId, matchCode: claim.matchCode }),
  })).status, 200);
  const redeemed = await fetch(`${base}/qr/phone/redeem`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ codeId: pairing.codeId, verifier }),
  });
  assert.equal(redeemed.status, 200);
  const phoneSession = await redeemed.json();
  const tokenHash = crypto.createHash("sha256").update(phoneSession.token).digest("hex");
  const encrypted = openDatabase(path.join(directory, "peo-yame.sqlite"), key);
  assert.equal(encrypted.prepare("SELECT idle_timeout_minutes FROM sessions WHERE token_hash=?").get(tokenHash).idle_timeout_minutes, 30);
  encrypted.prepare("UPDATE sessions SET last_seen_at=? WHERE token_hash=?").run(
    new Date(Date.now() - 31 * 60000).toISOString(),
    tokenHash,
  );
  encrypted.close();
  assert.equal((await fetch(`${base}/account`, { headers: { authorization: `Bearer ${phoneSession.token}` } })).status, 401);
});

test("approved QR codes cannot be redeemed after their expiry", async (t) => {
  const { base, directory, key } = await startBackend(t);
  const account = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Expiry Farmer", phone: "76789012", password: "expiry-test-password" }),
  }).then((response) => response.json());
  const verifier = "expiry-test-verifier-0123456789abcdef";
  const verifierHash = crypto.createHash("sha256").update(verifier).digest("hex");
  const created = await fetch(`${base}/qr/web/create`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ verifierHash }),
  }).then((response) => response.json());
  const auth = { authorization: `Bearer ${account.token}`, "content-type": "application/json" };
  assert.equal((await fetch(`${base}/qr/web/scan`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ codeId: created.codeId }),
  })).status, 200);
  assert.equal((await fetch(`${base}/qr/web/approve`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ codeId: created.codeId, matchCode: created.matchCode }),
  })).status, 200);

  const encrypted = openDatabase(path.join(directory, "peo-yame.sqlite"), key);
  encrypted.prepare("UPDATE pairings SET expires_at=? WHERE id_hash=?").run(
    new Date(Date.now() - 1000).toISOString(),
    crypto.createHash("sha256").update(created.codeId).digest("hex"),
  );
  encrypted.close();

  const status = await fetch(`${base}/qr/web/status?codeId=${encodeURIComponent(created.codeId)}&verifier=${encodeURIComponent(verifier)}`).then((response) => response.json());
  assert.equal(status.state, "expired");
  assert.equal((await fetch(`${base}/qr/web/redeem`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ codeId: created.codeId, verifier }),
  })).status, 401);
});

test("LAN listener and phone QR use the configured private interface", async (t) => {
  const lanHost = "127.0.0.2";
  const { base } = await startBackend(t, { lanHost });
  const desktop = new URL(base);
  const phoneBase = `${desktop.protocol}//${lanHost}:${desktop.port}/api`;
  assert.equal((await fetch(`${phoneBase}/health`)).status, 200);
  const account = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "LAN Farmer", phone: "77890123", password: "lan-test-password" }),
  }).then((response) => response.json());
  const pairing = await fetch(`${base}/qr/phone/create`, {
    method: "POST",
    headers: { authorization: `Bearer ${account.token}`, "content-type": "application/json" },
    body: JSON.stringify({ password: "lan-test-password" }),
  }).then((response) => response.json());
  assert.equal(pairing.backendAddress, `http://${lanHost}:${desktop.port}`);
});

test("phone pairing creation requires password and authenticator re-check", async (t) => {
  const { base } = await startBackend(t);
  const account = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Pairing Farmer", phone: "73456789", password: "pairing-test-password" }),
  }).then((response) => response.json());
  const auth = { authorization: `Bearer ${account.token}`, "content-type": "application/json" };
  const missing = await fetch(`${base}/qr/phone/create`, { method: "POST", headers: auth, body: "{}" });
  assert.equal(missing.status, 401);
  const wrong = await fetch(`${base}/qr/phone/create`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: "wrong-password" }),
  });
  assert.equal(wrong.status, 401);
  const accepted = await fetch(`${base}/qr/phone/create`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: "pairing-test-password" }),
  });
  assert.equal(accepted.status, 200);
});
