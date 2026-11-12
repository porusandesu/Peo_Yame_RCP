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
    async restart(extraEnv = {}) {
      if (child.exitCode === null && child.signalCode === null) {
        child.kill("SIGTERM");
        await new Promise((resolve) => child.once("exit", resolve));
      }
      child = spawn(process.execPath, ["src/server.js"], {
        cwd: new URL("..", import.meta.url),
        env: { ...env, ...extraEnv },
        stdio: "ignore",
      });
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
  const enabled = await fetch(`${base}/authenticator/enable`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ code: currentTotp(setup.secret) }),
  });
  assert.equal(enabled.status, 200);
  const enabledSession = await enabled.json();
  assert.notEqual(enabledSession.token, account.token);
  assert.equal((await fetch(`${base}/account`, {
    headers: { authorization: `Bearer ${account.token}` },
  })).status, 401);
  auth.authorization = `Bearer ${enabledSession.token}`;
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

test("authenticator changes revoke other sessions and retain the current session", async (t) => {
  const { base } = await startBackend(t);
  const registration = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Session Farmer", phone: "74678901", password: "session-password" }),
  });
  const account = await registration.json();
  const auth = { authorization: `Bearer ${account.token}`, "content-type": "application/json" };
  const setup = await fetch(`${base}/authenticator/setup`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: "session-password" }),
  }).then((result) => result.json());
  const secondSession = await fetch(`${base}/account/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ phone: "74678901", password: "session-password" }),
  }).then((result) => result.json());
  const enabled = await fetch(`${base}/authenticator/enable`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ code: currentTotp(setup.secret) }),
  });
  assert.equal(enabled.status, 200);
  const enabledData = await enabled.json();
  assert.equal(enabledData.revokedSessions, 1);
  assert.notEqual(enabledData.token, account.token);
  assert.equal((await fetch(`${base}/account`, {
    headers: { authorization: `Bearer ${secondSession.token}` },
  })).status, 401);
  assert.equal((await fetch(`${base}/account`, { headers: { authorization: `Bearer ${account.token}` } })).status, 401);
  let currentAuth = { authorization: `Bearer ${enabledData.token}`, "content-type": "application/json" };
  assert.equal((await fetch(`${base}/account`, { headers: currentAuth })).status, 200);

  const thirdLogin = await fetch(`${base}/account/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      phone: "74678901",
      password: "session-password",
      totpCode: currentTotp(setup.secret),
    }),
  });
  assert.equal(thirdLogin.status, 200);
  const thirdSession = await thirdLogin.json();
  const disabledResponse = await fetch(`${base}/authenticator/disable`, {
    method: "POST",
    headers: currentAuth,
    body: JSON.stringify({ password: "session-password", code: currentTotp(setup.secret) }),
  });
  assert.equal(disabledResponse.status, 200);
  const disabledData = await disabledResponse.json();
  assert.equal(disabledData.revokedSessions, 1);
  assert.notEqual(disabledData.token, enabledData.token);
  assert.equal((await fetch(`${base}/account`, {
    headers: { authorization: `Bearer ${thirdSession.token}` },
  })).status, 401);
  assert.equal((await fetch(`${base}/account`, { headers: currentAuth })).status, 401);
  currentAuth = { authorization: `Bearer ${disabledData.token}`, "content-type": "application/json" };
  assert.equal((await fetch(`${base}/account`, { headers: currentAuth })).status, 200);
  const sessionsAfterDisable = await fetch(`${base}/account/sessions`, { headers: currentAuth }).then((result) => result.json());
  assert.equal(sessionsAfterDisable.length, 1);
  assert.equal(sessionsAfterDisable[0].totpVerified, false);
});

test("security activity is authenticated and scoped to the signed-in account", async (t) => {
  const { base } = await startBackend(t);
  const first = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Activity Farmer", phone: "74789012", password: "activity-password" }),
  }).then((result) => result.json());
  assert.equal((await fetch(`${base}/account/security-activity`)).status, 401);
  const failedSignIn = await fetch(`${base}/account/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ phone: "74789012", password: "wrong-activity-password" }),
  });
  assert.equal(failedSignIn.status, 401);
  const signIn = await fetch(`${base}/account/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ phone: "74789012", password: "activity-password" }),
  });
  assert.equal(signIn.status, 200);
  const firstEvents = await fetch(`${base}/account/security-activity`, {
    headers: { authorization: `Bearer ${first.token}` },
  }).then((result) => result.json());
  assert.deepEqual(firstEvents.map((event) => event.event), ["sign_in", "sign_in_failed", "account_created"]);
  assert.ok(firstEvents.every((event) => Object.keys(event).sort().join(",") === "createdAt,event,id"));

  const second = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Other Farmer", phone: "74890123", password: "activity-password" }),
  }).then((result) => result.json());
  const secondEvents = await fetch(`${base}/account/security-activity`, {
    headers: { authorization: `Bearer ${second.token}` },
  }).then((result) => result.json());
  assert.deepEqual(secondEvents.map((event) => event.event), ["account_created"]);
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
  let sessionCookie = cookies.find((cookie) => cookie.startsWith("py_session="))?.split(";")[0];
  let csrfCookie = cookies.find((cookie) => cookie.startsWith("py_csrf="))?.split(";")[0];
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
  const setup = await fetch(`${base}/authenticator/setup`, {
    method: "POST",
    headers: { ...headers, "x-csrf-token": csrf },
    body: JSON.stringify({ password: "cookie-test-password" }),
  }).then((response) => response.json());
  const enabled = await fetch(`${base}/authenticator/enable`, {
    method: "POST",
    headers: { ...headers, "x-csrf-token": csrf },
    body: JSON.stringify({ code: currentTotp(setup.secret) }),
  });
  assert.equal(enabled.status, 200);
  assert.equal((await enabled.json()).token, undefined);
  const rotatedCookies = enabled.headers.getSetCookie();
  sessionCookie = rotatedCookies.find((cookie) => cookie.startsWith("py_session="))?.split(";")[0];
  csrfCookie = rotatedCookies.find((cookie) => cookie.startsWith("py_csrf="))?.split(";")[0];
  assert.ok(sessionCookie);
  assert.ok(csrfCookie);
  assert.equal((await fetch(`${base}/account`, { headers: { cookie: cookies.find((cookie) => cookie.startsWith("py_session="))?.split(";")[0] } })).status, 401);
  assert.equal((await fetch(`${base}/account`, { headers: { cookie: sessionCookie } })).status, 200);

  const disabled = await fetch(`${base}/authenticator/disable`, {
    method: "POST",
    headers: {
      origin,
      cookie: `${sessionCookie}; ${csrfCookie}`,
      "x-csrf-token": csrfCookie.slice("py_csrf=".length),
      "content-type": "application/json",
    },
    body: JSON.stringify({ password: "cookie-test-password", code: currentTotp(setup.secret) }),
  });
  assert.equal(disabled.status, 200);
  assert.equal((await disabled.json()).token, undefined);
  const disabledCookies = disabled.headers.getSetCookie();
  const previousSessionCookie = sessionCookie;
  sessionCookie = disabledCookies.find((cookie) => cookie.startsWith("py_session="))?.split(";")[0];
  csrfCookie = disabledCookies.find((cookie) => cookie.startsWith("py_csrf="))?.split(";")[0];
  assert.ok(sessionCookie);
  assert.ok(csrfCookie);
  assert.equal((await fetch(`${base}/account`, { headers: { cookie: previousSessionCookie } })).status, 401);
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

test("login locks the phone and IP after five failures without locking other accounts", async (t) => {
  const { base, directory, key } = await startBackend(t);
  const register = async (name, phone, password) => fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name, phone, password }),
  }).then((response) => response.json());
  const lockedAccount = await register("Locked Farmer", "75678903", "lockout-test-password");
  await register("Other Farmer", "75678904", "other-lockout-password");
  const login = (phone, password) => fetch(`${base}/account/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ phone, password }),
  });
  const genericMessage = "Phone number or password is incorrect.";
  for (let attempt = 0; attempt < 5; attempt++) {
    const failed = await login("75678903", "incorrect-lockout-password");
    assert.equal(failed.status, 401);
    assert.equal((await failed.json()).error, genericMessage);
  }
  const locked = await login("75678903", "lockout-test-password");
  assert.equal(locked.status, 401);
  assert.equal((await locked.json()).error, genericMessage);
  const lockoutEvents = await fetch(`${base}/account/security-activity`, {
    headers: { authorization: `Bearer ${lockedAccount.token}` },
  }).then((response) => response.json());
  assert.ok(lockoutEvents.some((event) => event.event === "sign_in_locked"));
  assert.ok(lockoutEvents.some((event) => event.event === "sign_in_blocked"));
  assert.equal((await login("75678904", "other-lockout-password")).status, 200);

  const encrypted = openDatabase(path.join(directory, "peo-yame.sqlite"), key);
  const lockout = encrypted.prepare("SELECT attempt_key,locked_until FROM login_lockouts").get();
  assert.ok(lockout);
  assert.ok(Date.parse(lockout.locked_until) > Date.now());
  encrypted.prepare("UPDATE login_lockouts SET locked_until=? WHERE attempt_key=?").run(
    new Date(Date.now() - 1000).toISOString(),
    lockout.attempt_key,
  );
  encrypted.close();
  assert.equal((await login("75678903", "lockout-test-password")).status, 200);
});

test("guided demo live simulation syncs readings to a second QR session", async (t) => {
  const { base, directory, key } = await startBackend(t);
  const demo = await fetch(`${base}/demo/start`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  });
  assert.equal(demo.status, 201);
  const demoSession = await demo.json();
  const auth = { authorization: `Bearer ${demoSession.token}`, "content-type": "application/json" };
  assert.equal((await fetch(`${base}/qr/phone/create`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: demoSession.demoPassword }),
  })).status, 200);
  const verifier = "shared-demo-verifier-0123456789abcdef";
  const verifierHash = crypto.createHash("sha256").update(verifier).digest("hex");
  const pairing = await fetch(`${base}/qr/web/create`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ verifierHash }),
  }).then((response) => response.json());
  assert.equal((await fetch(`${base}/qr/web/scan`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ codeId: pairing.codeId }),
  })).status, 200);
  assert.equal((await fetch(`${base}/qr/web/approve`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ codeId: pairing.codeId, matchCode: pairing.matchCode }),
  })).status, 200);
  const browserSession = await fetch(`${base}/qr/web/redeem`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ codeId: pairing.codeId, verifier }),
  }).then((response) => response.json());
  assert.equal(browserSession.isDemo, true);
  const encrypted = openDatabase(path.join(directory, "peo-yame.sqlite"), key);
  const browserTokenHash = crypto.createHash("sha256").update(browserSession.token).digest("hex");
  const browserSessionRow = encrypted.prepare("SELECT idle_timeout_minutes,expires_at FROM sessions WHERE token_hash=?").get(browserTokenHash);
  assert.equal(browserSessionRow.idle_timeout_minutes, 30);
  const demoTimeRemaining = Date.parse(browserSessionRow.expires_at) - Date.now();
  assert.ok(demoTimeRemaining > 116 * 60000 && demoTimeRemaining <= 2 * 60 * 60000);
  encrypted.close();

  const mobileAbort = new AbortController();
  const webAbort = new AbortController();
  t.after(() => { mobileAbort.abort(); webAbort.abort(); });
  const mobileStream = await fetch(`${base}/events`, { headers: auth, signal: mobileAbort.signal });
  const webStream = await fetch(`${base}/events`, {
    headers: { authorization: `Bearer ${browserSession.token}` },
    signal: webAbort.signal,
  });
  assert.equal(mobileStream.status, 200);
  assert.equal(webStream.status, 200);
  const mobileReader = mobileStream.body.getReader();
  const webReader = webStream.body.getReader();
  await Promise.all([readUntil(mobileReader, "event: connected"), readUntil(webReader, "event: connected")]);

  const startedAt = Date.now();
  const started = await fetch(`${base}/demo/simulation/start`, {
    method: "POST",
    headers: auth,
  });
  assert.equal(started.status, 200);
  const simulation = await started.json();
  assert.equal(simulation.intervalSeconds, 3);
  await Promise.all([readUntil(mobileReader, "event: reading"), readUntil(webReader, "event: reading")]);
  const status = await fetch(`${base}/status`, {
    headers: { authorization: `Bearer ${browserSession.token}` },
  }).then((response) => response.json());
  assert.equal(status.isDemo, true);
  assert.equal(status.reading.synthetic, true);
  assert.ok(Date.parse(status.reading.createdAt) >= startedAt - 1000);
  const generatedAlerts = await fetch(`${base}/alerts`, {
    headers: { authorization: `Bearer ${browserSession.token}` },
  }).then((response) => response.json());
  assert.equal(generatedAlerts[0].synthetic, 1);
  assert.match(generatedAlerts[0].message, /outside the Maize target band/);
  await new Promise((resolve) => setTimeout(resolve, simulation.intervalSeconds * 1000 + 150));
  const refreshedStatus = await fetch(`${base}/status`, {
    headers: { authorization: `Bearer ${browserSession.token}` },
  }).then((response) => response.json());
  assert.notEqual(refreshedStatus.reading.temperature, status.reading.temperature);
  assert.notEqual(refreshedStatus.reading.humidity, status.reading.humidity);
  const sensors = await fetch(`${base}/sensors`, {
    headers: { authorization: `Bearer ${browserSession.token}` },
  }).then((response) => response.json());
  assert.equal(sensors[0].online, true);
  assert.equal(sensors[0].latestReading.synthetic, 1);
  assert.equal((await fetch(`${base}/demo/simulation/stop`, {
    method: "POST",
    headers: { authorization: `Bearer ${browserSession.token}` },
  })).status, 200);
});

test("guided demo exposes a one-time password for real TOTP setup and persists its run-sheet checklist", async (t) => {
  const { base } = await startBackend(t);
  const response = await fetch(`${base}/demo/start`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  });
  assert.equal(response.status, 201);
  const demo = await response.json();
  assert.equal(typeof demo.demoPassword, "string");
  assert.ok(demo.demoPassword.length >= 32);
  const auth = { authorization: `Bearer ${demo.token}`, "content-type": "application/json" };
  const account = await fetch(`${base}/account`, { headers: auth }).then((result) => result.json());
  assert.match(account.phone, /^demo-[a-f0-9]+@peo-yame\.invalid$/);
  assert.equal((await fetch(`${base}/authenticator/setup`, {
    method: "POST",
    headers: auth,
    body: "{}",
  })).status, 401);
  const setupResponse = await fetch(`${base}/authenticator/setup`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: demo.demoPassword }),
  });
  assert.equal(setupResponse.status, 200);
  const setup = await setupResponse.json();
  const enabled = await fetch(`${base}/authenticator/enable`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ code: currentTotp(setup.secret) }),
  });
  assert.equal(enabled.status, 200);
  const rotatedDemo = await enabled.json();
  const rotatedAuth = { authorization: `Bearer ${rotatedDemo.token}`, "content-type": "application/json" };

  const initial = await fetch(`${base}/demo/checklist`, { headers: rotatedAuth }).then((result) => result.json());
  assert.equal(initial.steps.length, 16);
  assert.equal(initial.steps[0].completed, false);
  assert.equal((await fetch(`${base}/demo/checklist/1`, {
    method: "PATCH",
    headers: rotatedAuth,
    body: JSON.stringify({ completed: true }),
  })).status, 200);
  const updated = await fetch(`${base}/demo/checklist`, { headers: rotatedAuth }).then((result) => result.json());
  assert.equal(updated.steps[0].completed, true);
  assert.equal((await fetch(`${base}/demo/checklist/17`, {
    method: "PATCH",
    headers: rotatedAuth,
    body: JSON.stringify({ completed: true }),
  })).status, 400);
});

test("guided demo storage and alert estimates are ranged, disclosed, and hidden when stale", async (t) => {
  const { base, directory, key } = await startBackend(t);
  const demo = await fetch(`${base}/demo/start`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  }).then((response) => response.json());
  const auth = { authorization: `Bearer ${demo.token}`, "content-type": "application/json" };
  assert.equal((await fetch(`${base}/demo/sensor-reading`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ sensorId: "PY-DEMO-1" }),
  })).status, 201);
  const createdSite = await fetch(`${base}/sites`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ name: "Demo storage", crop: "Maize" }),
  }).then((response) => response.json());
  const sensor = (await fetch(`${base}/sensors?unlinked=true`, { headers: auth }).then((response) => response.json()))[0];
  assert.equal((await fetch(`${base}/sensors/${sensor.id}/link`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ siteId: createdSite.id }),
  })).status, 200);
  const site = (await fetch(`${base}/sites`, { headers: auth }).then((response) => response.json()))
    .find((item) => item.name === "Demo storage");
  assert.ok(site.estimate);
  assert.equal(site.estimate.rangeWeeks.length, 2);
  assert.match(site.estimate.disclaimer, /Check your crops by hand/);

  assert.equal((await fetch(`${base}/demo/breach`, { method: "POST", headers: auth })).status, 201);
  const alerts = await fetch(`${base}/alerts`, { headers: auth }).then((response) => response.json());
  assert.ok(alerts[0].estimate);
  assert.equal(alerts[0].estimate.rangeWeeks.length, 2);
  assert.match(alerts[0].estimate.disclaimer, /does not inspect your crop/);

  const encrypted = openDatabase(path.join(directory, "peo-yame.sqlite"), key);
  const userId = encrypted.prepare("SELECT id FROM users WHERE is_demo=1").get().id;
  encrypted.prepare("UPDATE readings SET created_at=? WHERE user_id=?").run(
    new Date(Date.now() - 16 * 60 * 1000).toISOString(),
    userId,
  );
  encrypted.close();
  const staleSite = (await fetch(`${base}/sites`, { headers: auth }).then((response) => response.json()))
    .find((item) => item.name === "Demo storage");
  assert.equal(staleSite.estimate, null);
  const staleAlerts = await fetch(`${base}/alerts`, { headers: auth }).then((response) => response.json());
  assert.equal(staleAlerts[0].estimate, null);
});

test("trend responses keep timestamped chart points bounded and summarize the full range", async (t) => {
  const { base, directory, key } = await startBackend(t);
  const demo = await fetch(`${base}/demo/start`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  }).then((response) => response.json());
  const database = openDatabase(path.join(directory, "peo-yame.sqlite"), key);
  const userId = database.prepare("SELECT id FROM users WHERE is_demo=1").get().id;
  const insert = database.prepare(
    "INSERT INTO readings(user_id,temperature,humidity,created_at,synthetic) VALUES(?,?,?,?,1)",
  );
  database.transaction(() => {
    for (let index = 0; index < 505; index++) {
      insert.run(
        userId,
        index === 0 ? 5 : index === 504 ? 40 : 20,
        index === 0 ? 10 : index === 504 ? 99 : 60,
        new Date(Date.now() - 10000 + index * 10).toISOString(),
      );
    }
  })();
  database.close();

  const response = await fetch(`${base}/readings/trends?range=24h`, {
    headers: { authorization: `Bearer ${demo.token}` },
  });
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.equal(result.range, "24h");
  assert.ok(result.count >= 529);
  assert.ok(result.points.length <= 500 && result.points.length >= 496);
  assert.ok(result.points.every((point) => point.created_at && Number.isFinite(point.temperature) && Number.isFinite(point.humidity)));
  assert.ok(result.points.some((point) => point.temperature === 5));
  assert.ok(result.points.some((point) => point.temperature === 40));
  assert.ok(result.points.some((point) => point.humidity === 10));
  assert.ok(result.points.some((point) => point.humidity === 99));
  assert.deepEqual(result.summary.temperature, { low: 5, high: 40 });
  assert.deepEqual(result.summary.humidity, { low: 10, high: 99 });
  assert.equal((await fetch(`${base}/readings/trends?range=weekly`, {
    headers: { authorization: `Bearer ${demo.token}` },
  })).status, 400);
});

test("backend connection QR contains only the backend address and purpose", async (t) => {
  const { base } = await startBackend(t);
  const response = await fetch(`${base}/backend/qr`);
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.ok(result.qrDataUrl.startsWith("data:image/png;base64,"));
  const payload = JSON.parse(result.payload);
  assert.equal(payload.flow, "backend");
  assert.equal(payload.baseUrl, result.baseUrl);
  assert.equal(Object.hasOwn(payload, "token"), false);
  assert.equal(Object.hasOwn(payload, "codeId"), false);
});

test("phone pairing renewal expires the old code and stays bound to its owner session", async (t) => {
  const { base } = await startBackend(t);
  const account = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Pairing Farmer", phone: "76789013", password: "pairing-test-password" }),
  }).then((response) => response.json());
  const auth = { authorization: `Bearer ${account.token}`, "content-type": "application/json" };
  const first = await fetch(`${base}/qr/phone/create`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: "pairing-test-password" }),
  }).then((response) => response.json());
  const renewedResponse = await fetch(`${base}/qr/phone/renew`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ codeId: first.codeId }),
  });
  assert.equal(renewedResponse.status, 200);
  const renewed = await renewedResponse.json();
  assert.notEqual(renewed.codeId, first.codeId);
  assert.equal((await fetch(`${base}/qr/phone/owner-status?codeId=${encodeURIComponent(first.codeId)}`, {
    headers: auth,
  }).then((response) => response.json())).state, "expired");

  const other = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Other Farmer", phone: "76789014", password: "other-pairing-password" }),
  }).then((response) => response.json());
  const denied = await fetch(`${base}/qr/phone/renew`, {
    method: "POST",
    headers: { authorization: `Bearer ${other.token}`, "content-type": "application/json" },
    body: JSON.stringify({ codeId: renewed.codeId }),
  });
  assert.equal(denied.status, 404);
});

test("phone pairing cancellation is verifier-bound and can be restarted", async (t) => {
  const { base } = await startBackend(t);
  const account = await fetch(`${base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Cancel Farmer", phone: "76789015", password: "cancel-pairing-password" }),
  }).then((response) => response.json());
  const auth = { authorization: `Bearer ${account.token}`, "content-type": "application/json" };
  const pairing = await fetch(`${base}/qr/phone/create`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ password: "cancel-pairing-password" }),
  }).then((response) => response.json());
  const verifier = "cancel-phone-verifier-0123456789abcdef";
  const verifierHash = crypto.createHash("sha256").update(verifier).digest("hex");
  assert.equal((await fetch(`${base}/qr/phone/claim`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ codeId: pairing.shortCode, verifierHash }),
  })).status, 200);
  assert.equal((await fetch(`${base}/qr/phone/withdraw`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ codeId: pairing.codeId, verifier: "wrong-verifier" }),
  })).status, 401);
  const withdrawn = await fetch(`${base}/qr/phone/withdraw`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ codeId: pairing.codeId, verifier }),
  });
  assert.equal(withdrawn.status, 200);
  assert.equal((await withdrawn.json()).state, "cancelled");
  assert.equal((await fetch(`${base}/qr/phone/status?codeId=${encodeURIComponent(pairing.codeId)}&verifier=${encodeURIComponent(verifier)}`)
    .then((response) => response.json())).state, "cancelled");

  const renewed = await fetch(`${base}/qr/phone/renew`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ codeId: pairing.codeId }),
  });
  assert.equal(renewed.status, 200);
  assert.notEqual((await renewed.json()).codeId, pairing.codeId);
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
  const activity = await fetch(`${base}/account/security-activity`, {
    headers: { authorization: `Bearer ${account.token}` },
  }).then((response) => response.json());
  assert.ok(activity.some((event) => event.event === "web_qr_expired"));
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

test("optional demo endpoints reject invalid credentials instead of falling back to shared data", async (t) => {
  const { base } = await startBackend(t);
  const publicReads = [
    "/crops",
    "/status",
    "/readings/trends?range=24h",
    "/readings/export?format=csv",
    "/alerts",
  ];
  for (const route of publicReads) {
    assert.equal((await fetch(`${base}${route}`)).status, 200, route);
    for (const headers of [
      { authorization: "Bearer expired-or-invalid-token" },
      { cookie: "py_session=expired-or-invalid-token" },
    ]) {
      assert.equal((await fetch(`${base}${route}`, { headers })).status, 401, route);
    }
  }
  assert.equal((await fetch(`${base}/events`, {
    headers: { authorization: "Bearer expired-or-invalid-token" },
  })).status, 401);
  assert.equal((await fetch(`${base}/crop-selection`, {
    method: "POST",
    headers: { "content-type": "application/json", cookie: "py_csrf=anonymous" },
    body: JSON.stringify({ crop: "Maize" }),
  })).status, 200);
  assert.equal((await fetch(`${base}/crop-selection`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer expired-or-invalid-token" },
    body: JSON.stringify({ crop: "Maize" }),
  })).status, 401);
});

test("demo reset and expired-session cleanup remove temporary account records", async (t) => {
  const backend = await startBackend(t);
  const createDemo = async () => fetch(`${backend.base}/demo/start`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  }).then((response) => response.json());
  const assertNoDemoRecords = (userId) => {
    const database = openDatabase(path.join(backend.directory, "peo-yame.sqlite"), backend.key);
    try {
      for (const [table, column] of [["users", "id"], ["sessions", "user_id"], ["sites", "user_id"], ["sensors", "user_id"], ["custom_crops", "user_id"], ["readings", "user_id"], ["alerts", "user_id"], ["preferences", "user_id"], ["demo_checklist", "user_id"], ["security_log", "user_id"]]) {
        const row = database.prepare(`SELECT COUNT(*) AS count FROM ${table} WHERE ${column}=?`).get(userId);
        assert.equal(row.count, 0, `${table} records remain for deleted demo user`);
      }
      assert.equal(database.prepare("SELECT COUNT(*) AS count FROM pairings WHERE owner_user_id=? OR device_user_id=?").get(userId, userId).count, 0);
    } finally {
      database.close();
    }
  };
  const resetDemo = await createDemo();
  const resetAuth = { authorization: `Bearer ${resetDemo.token}`, "content-type": "application/json" };
  const resetDb = openDatabase(path.join(backend.directory, "peo-yame.sqlite"), backend.key);
  const resetUserId = resetDb.prepare("SELECT id FROM users WHERE is_demo=1").get().id;
  resetDb.close();
  assert.equal((await fetch(`${backend.base}/crop-selection`, {
    method: "POST",
    headers: resetAuth,
    body: JSON.stringify({ crop: "Sorghum" }),
  })).status, 200);
  assert.equal((await fetch(`${backend.base}/crops`, {
    method: "POST",
    headers: resetAuth,
    body: JSON.stringify({
      name: "Test Yam",
      category: "crop",
      temperatureMin: 10,
      temperatureMax: 25,
      humidityMin: 40,
      humidityMax: 70,
      baselineWeeks: 8,
    }),
  })).status, 201);
  assert.equal((await fetch(`${backend.base}/demo/checklist/1`, {
    method: "PATCH",
    headers: resetAuth,
    body: JSON.stringify({ completed: true }),
  })).status, 200);
  assert.equal((await fetch(`${backend.base}/qr/phone/create`, {
    method: "POST",
    headers: resetAuth,
    body: JSON.stringify({ password: resetDemo.demoPassword }),
  })).status, 200);
  const resetData = openDatabase(path.join(backend.directory, "peo-yame.sqlite"), backend.key);
  resetData.prepare("INSERT INTO security_log(user_id,event,created_at) VALUES(?,?,?)").run(resetUserId, "test_event", new Date().toISOString());
  resetData.close();
  assert.equal((await fetch(`${backend.base}/demo/reset`, {
    method: "POST",
    headers: { authorization: `Bearer ${resetDemo.token}` },
  })).status, 200);
  assertNoDemoRecords(resetUserId);

  const expiredDemo = await createDemo();
  const expiredDb = openDatabase(path.join(backend.directory, "peo-yame.sqlite"), backend.key);
  const expiredUserId = expiredDb.prepare("SELECT id FROM users WHERE is_demo=1").get().id;
  expiredDb.prepare("INSERT INTO preferences(user_id,selected_crop,updated_at) VALUES(?,?,?)")
    .run(expiredUserId, "Sorghum", new Date().toISOString());
  expiredDb.prepare("UPDATE sessions SET expires_at=? WHERE user_id=?")
    .run(new Date(Date.now() - 1000).toISOString(), expiredUserId);
  expiredDb.close();
  await backend.restart();
  assertNoDemoRecords(expiredUserId);
  assert.equal((await fetch(`${backend.base}/status`, {
    headers: { authorization: `Bearer ${expiredDemo.token}` },
  })).status, 401);
});

test("instance reset invalidates active pairings while preserving login accounts", async (t) => {
  const backend = await startBackend(t);
  const account = await fetch(`${backend.base}/account/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Reset Farmer", phone: "76789016", password: "reset-pairing-password" }),
  }).then((response) => response.json());
  const demo = await fetch(`${backend.base}/demo/start`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  }).then((response) => response.json());
  const pairing = await fetch(`${backend.base}/qr/phone/create`, {
    method: "POST",
    headers: { authorization: `Bearer ${demo.token}`, "content-type": "application/json" },
    body: JSON.stringify({ password: demo.demoPassword }),
  });
  assert.equal(pairing.status, 200);
  await backend.restart({ PEO_YAME_RESET_INSTANCE: "true" });
  assert.equal((await fetch(`${backend.base}/account`, {
    headers: { authorization: `Bearer ${account.token}` },
  })).status, 200);
  const database = openDatabase(path.join(backend.directory, "peo-yame.sqlite"), backend.key);
  try {
    assert.equal(database.prepare("SELECT COUNT(*) AS count FROM pairings").get().count, 0);
    assert.equal(database.prepare("SELECT COUNT(*) AS count FROM users").get().count, 2);
  } finally {
    database.close();
  }
});

test("demo account creation is rate limited before allocating additional accounts", async (t) => {
  const backend = await startBackend(t);
  for (let attempt = 0; attempt < 5; attempt++) {
    const response = await fetch(`${backend.base}/demo/start`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    });
    assert.equal(response.status, 201);
  }
  const limited = await fetch(`${backend.base}/demo/start`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  });
  assert.equal(limited.status, 429);
  const database = openDatabase(path.join(backend.directory, "peo-yame.sqlite"), backend.key);
  try {
    assert.equal(database.prepare("SELECT COUNT(*) AS count FROM users WHERE is_demo=1").get().count, 5);
  } finally {
    database.close();
  }
});
