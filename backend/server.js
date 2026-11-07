/**
 * Storage Monitor - Demo Backend
 * ------------------------------
 * A small local API that stands in for the real sensor pipeline while the
 * ESP32 + GSM hardware isn't built yet. It generates realistic-looking
 * temperature/humidity readings on an interval, evaluates them against a
 * threshold, persists readings in SQLite, and streams updates to each client.
 *
 * TO SWITCH TO REAL DATA LATER:
 * Replace the `generateReading()` function with sensor input. The database
 * and route response shapes can remain in place for the real sensor pipeline.
 * The route handlers and response shapes can stay exactly the same, so the
 * Android app and dashboard don't need to change at all.
 */

const express = require("express");
const cors = require("cors");
const fs = require("node:fs");
const path = require("node:path");
const cropDatabase = require("./database");
const { dataDirectory } = require("./runtime_paths");
const { createFarmerAuth } = require("./farmer_auth");
const { encodeBase32, verifyAuthenticatorCode } = require("./authenticator");
const crypto = require("node:crypto");
const QRCode = require("qrcode");

const app = express();
const allowedOrigins = (process.env.CORS_ORIGINS || "").split(",").map((value) => value.trim()).filter(Boolean);
app.use(cors({ origin: allowedOrigins.length ? allowedOrigins : process.env.NODE_ENV === "production" ? false : true }));
app.use(express.json({ limit: "32kb" }));
app.use(express.static(path.join(__dirname, "public")));

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || (process.env.NODE_ENV === "production" ? "127.0.0.1" : "0.0.0.0");
const AUTH_ENABLED = process.env.AUTH_ENABLED === "true" || process.env.NODE_ENV === "production";
const farmerAuth = createFarmerAuth(cropDatabase);
cropDatabase.cleanupExpiredSessions();
cropDatabase.cleanupAuthChallenges();
const ACTION_LOG_PATH = process.env.ACTION_LOG_PATH || path.join(dataDirectory, "actions.jsonl");
const MAX_ACTIONS = 2500;
fs.mkdirSync(path.dirname(ACTION_LOG_PATH), { recursive: true });
const eventClients = new Set();

function broadcastUpdate(type = "reading") {
  const event = `data: ${JSON.stringify({ type, updatedAt: new Date().toISOString() })}\n\n`;
  for (const client of eventClients) {
    try {
      client.write(event);
    } catch (_) {
      eventClients.delete(client);
    }
  }
}

function loadActionLog() {
  if (!fs.existsSync(ACTION_LOG_PATH)) return [];
  return fs.readFileSync(ACTION_LOG_PATH, "utf8")
    .split("\n")
    .filter(Boolean)
    .flatMap((line) => {
      try {
        return [JSON.parse(line)];
      } catch (_) {
        return [];
      }
    })
    .slice(-MAX_ACTIONS);
}

let actions = loadActionLog();
let nextActionId = actions.reduce((next, action) => Math.max(next, action.id + 1), 1);

function logAction(action, { source = "backend", actor = "Olerato.M", details = {} } = {}) {
  const entry = {
    id: nextActionId++,
    timestamp: new Date().toISOString(),
    actor,
    source,
    action,
    details,
  };
  actions.push(entry);
  if (actions.length > MAX_ACTIONS) actions = actions.slice(-MAX_ACTIONS);
  if (actions.length === MAX_ACTIONS) {
    fs.writeFileSync(ACTION_LOG_PATH, `${actions.map((item) => JSON.stringify(item)).join("\n")}\n`);
  } else {
    fs.appendFileSync(ACTION_LOG_PATH, `${JSON.stringify(entry)}\n`);
  }
  return entry;
}

function markdownCell(value) {
  return String(value ?? "").replaceAll("|", "\\|").replace(/[\r\n]+/g, " ");
}

function csvCell(value, protectFormula = false) {
  let text = String(value ?? "");
  if (protectFormula && /^[\s]*[=+@\-]/.test(text)) text = `'${text}`;
  return `"${text.replaceAll('"', '""')}"`;
}

// ---- Config: mirrors your ER diagram's THRESHOLD table ----
const thresholds = Object.fromEntries(cropDatabase.listCrops().map((crop) => [crop.commodity, crop]));
let threshold = cropDatabase.getCrop(cropDatabase.activeCropName()) || thresholds.Maize;

// ---- In-memory "database" (swap for real DB queries later) ----
if (process.env.NODE_ENV !== "production" && process.env.SEED_DEMO_HISTORY !== "false") cropDatabase.seedDemoHistory();
let readings = cropDatabase.recentReadings(200);
// Keep one compact aggregate per hour from SQLite, then add live minute buckets.
let trendBuckets = cropDatabase.trendHistory(new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString()).map((point) => ({
  minute: point.recordedAt.slice(0, 16),
  commodity: point.commodity,
  temperatureTotal: Number(point.temperature) * Number(point.count),
  humidityTotal: Number(point.humidity) * Number(point.count),
  count: Number(point.count),
  syntheticCount: Number(point.syntheticCount),
  liveCount: Number(point.liveCount),
}));
let alerts = [];
let smsLog = [];
let incidents = [];
let nextReadingId = readings.reduce((next, item) => Math.max(next, item.id + 1), 1);
let nextAlertId = 1;
let nextIncidentId = 1;
let demoBreachActive = false;
let demoBreachTimeout;
let demoBreachCount = 0;

function latestActiveReading() {
  for (let index = readings.length - 1; index >= 0; index--) {
    if (readings[index].commodity === threshold.commodity) return readings[index];
  }
  return null;
}

function recordReading(temperature, humidity, site = "default", dataSource = "simulation") {
  const reading = {
    id: nextReadingId++,
    site,
    commodity: threshold.commodity,
    dataSource,
    sensorId: dataSource === "sensor" ? site : null,
    temperature: Math.round(temperature * 10) / 10,
    humidity: Math.round(humidity * 10) / 10,
    recordedAt: new Date().toISOString(),
  };

  cropDatabase.saveReading(reading);
  readings.push(reading);
  if (readings.length > 200) readings.shift(); // keep memory bounded

  const minute = reading.recordedAt.slice(0, 16);
  let bucket;
  for (let index = trendBuckets.length - 1; index >= 0; index--) {
    const candidate = trendBuckets[index];
    if (candidate.minute === minute && candidate.commodity === threshold.commodity) {
      bucket = candidate;
      break;
    }
    if (candidate.minute < minute) break;
  }
  if (
    !bucket ||
    bucket.minute !== minute ||
    bucket.commodity !== threshold.commodity
  ) {
    bucket = {
      minute,
      commodity: threshold.commodity,
      temperatureTotal: 0,
      humidityTotal: 0,
      count: 0,
      syntheticCount: 0,
      liveCount: 0,
    };
    trendBuckets.push(bucket);
  }
  bucket.temperatureTotal += reading.temperature;
  bucket.humidityTotal += reading.humidity;
  bucket.count += 1;
  bucket.liveCount += 1;
  const oldestAllowed = Date.now() - 90 * 24 * 60 * 60 * 1000;
  while (trendBuckets.length && Date.parse(`${trendBuckets[0].minute}:00Z`) < oldestAllowed) {
    trendBuckets.shift();
  }

  const breached =
    reading.temperature < threshold.minTemp ||
    reading.temperature > threshold.maxTemp ||
    reading.humidity < threshold.minHumidity ||
    reading.humidity > threshold.maxHumidity;

  if (breached) {
    const sentAt = new Date().toISOString();
    const alert = {
      id: nextAlertId++,
      readingId: reading.id,
      commodity: threshold.commodity,
      reading: { ...reading },
      threshold: { ...threshold },
      message: `Threshold breached: ${reading.temperature}\u00b0C, ${reading.humidity}% RH`,
      sentAt,
      acknowledged: false,
    };
    alerts.unshift(alert);
    if (alerts.length > 50) alerts.pop();
    smsLog.unshift({
      to: "+26771234567",
      body: alert.message,
      createdAt: sentAt,
      status: "logged",
    });
    if (smsLog.length > 50) smsLog.pop();
  }

  broadcastUpdate();

  return reading;
}

function generateReading() {
  // Randomly drifts around a baseline, occasionally spikes to trigger an alert.
  const spike = Math.random() < 0.15;
  const tempRange = threshold.maxTemp - threshold.minTemp;
  const humidityRange = threshold.maxHumidity - threshold.minHumidity;
  const tempMidpoint = (threshold.minTemp + threshold.maxTemp) / 2;
  const humidityMidpoint = (threshold.minHumidity + threshold.maxHumidity) / 2;
  const temperature = spike
    ? threshold.maxTemp + Math.random() * Math.max(2, tempRange * 0.3)
    : tempMidpoint + (Math.random() - 0.5) * tempRange * 0.25;
  const humidity = spike
    ? Math.min(100, threshold.maxHumidity + Math.random() * Math.max(5, humidityRange * 0.25))
    : humidityMidpoint + (Math.random() - 0.5) * humidityRange * 0.25;

  return recordReading(temperature, humidity);
}

function generateSafeReading() {
  const tempRange = threshold.maxTemp - threshold.minTemp;
  const humidityRange = threshold.maxHumidity - threshold.minHumidity;
  const temperature = (threshold.minTemp + threshold.maxTemp) / 2;
  const humidity = (threshold.minHumidity + threshold.maxHumidity) / 2;
  return recordReading(
    temperature + (Math.random() - 0.5) * tempRange * 0.1,
    humidity + (Math.random() - 0.5) * humidityRange * 0.1,
  );
}

// Simulate a sensor pushing a new reading every 5 seconds
if (process.env.NODE_ENV !== "production") {
  setInterval(() => {
    try {
      if (!demoBreachActive) generateReading();
    } catch (error) {
      // A transient SQLite/constraint failure must not terminate the API loop.
      console.error(`Demo reading was not saved: ${error.message || error}`);
    }
  }, 5000);
  if (!latestActiveReading()) generateSafeReading();
} else if (readings.length) {
  if (!latestActiveReading()) {
    const lastCrop = readings[readings.length - 1].commodity;
    threshold = cropDatabase.getCrop(lastCrop) || threshold;
  }
}

// ---- Routes ----

app.get("/api/status", (req, res) => {
  const latest = latestActiveReading();
  const breached =
    latest &&
    (latest.temperature < threshold.minTemp ||
      latest.temperature > threshold.maxTemp ||
      latest.humidity < threshold.minHumidity ||
      latest.humidity > threshold.maxHumidity);
  res.json({ latest, threshold, breached: !!breached });
});

app.get("/api/health", (req, res) => {
  res.json({ status: "ok", time: new Date().toISOString(), demoMode: process.env.NODE_ENV !== "production", authEnabled: AUTH_ENABLED });
});

function authFailure(res, error) {
  const detail = String(error.stderr || error.message || "");
  const constraintFailure = /UNIQUE constraint failed|SQLITE_CONSTRAINT/i.test(detail);
  const status = Number(error.status) || (constraintFailure ? 409 : error instanceof TypeError ? 400 : 500);
  const message = status === 409 ? "That account, location, or sensor is already linked." : status === 500 ? "The request could not be completed." : error.message;
  res.status(status).json({ error: message });
}

function authUnavailable(res) {
  res.status(404).json({ error: "Farmer sign-in is disabled for this demo backend." });
}

function loginClientKey(req) {
  // In-memory limiter is per process only. Behind a reverse proxy set
  // TRUST_PROXY=true so the first X-Forwarded-For hop is used; otherwise the
  // direct socket address is used. This is a basic abuse brake, not a
  // production-grade distributed rate limit.
  if (process.env.TRUST_PROXY === "true") {
    const forwarded = String(req.headers["x-forwarded-for"] || "").split(",")[0].trim();
    if (forwarded) return forwarded.slice(0, 128);
  }
  return req.ip || req.socket?.remoteAddress || "unknown";
}

function bearerToken(req) {
  const header = req.get("authorization") || "";
  const match = header.match(/^Bearer\s+([A-Za-z0-9_-]{32,128})$/i);
  return match ? match[1] : null;
}

function requireFarmer(req, res, next) {
  if (!AUTH_ENABLED) return authUnavailable(res);
  const token = bearerToken(req);
  const farmer = farmerAuth.farmerForToken(token);
  if (!farmer) return res.status(401).json({ error: "Sign in to continue." });
  req.farmer = farmer;
  req.authToken = token;
  next();
}

function optionalFarmer(req, _res, next) {
  const token = bearerToken(req);
  if (token) {
    req.farmer = farmerAuth.farmerForToken(token);
    req.authToken = token;
  }
  next();
}

app.post("/api/auth/register", (req, res) => {
  if (!AUTH_ENABLED) return authUnavailable(res);
  try {
    const session = farmerAuth.register(req.body || {});
    return res.status(201).json(session);
  } catch (error) { return authFailure(res, error); }
});

app.post("/api/auth/login", (req, res) => {
  if (!AUTH_ENABLED) return authUnavailable(res);
  try {
    const session = farmerAuth.login({ ...(req.body || {}), clientKey: loginClientKey(req) });
    return res.json(session);
  } catch (error) { return authFailure(res, error); }
});

app.get("/api/auth/session", requireFarmer, (req, res) => res.json({ farmer: req.farmer }));

app.post("/api/auth/logout", requireFarmer, (req, res) => {
  farmerAuth.logout(req.authToken);
  res.json({ ok: true });
});

function validateQrServerBaseUrl(value) {
  if (value == null || value === "") return null;
  if (typeof value !== "string") throw new TypeError("Invalid backend address in sign-in QR request.");
  let uri;
  try { uri = new URL(value); } catch (_) { throw new TypeError("Invalid backend address in sign-in QR request."); }
  if (!["http:", "https:"].includes(uri.protocol) || !uri.hostname || uri.username || uri.password || !["", "/"].includes(uri.pathname) || uri.search || uri.hash) {
    throw new TypeError("Invalid backend address in sign-in QR request.");
  }
  return uri.origin;
}

async function createQrChallenge(purpose, farmerId = null, serverBaseUrl = null) {
  const challenge = crypto.randomBytes(32).toString("base64url");
  const expiresAt = new Date(Date.now() + 2 * 60 * 1000).toISOString();
  cropDatabase.createAuthChallenge(farmerAuth.tokenHash(challenge), purpose, farmerId, expiresAt);
  const direction = purpose === "web_login" ? "web-login" : "mobile-login";
  const server = validateQrServerBaseUrl(process.env.PUBLIC_BASE_URL || serverBaseUrl);
  const qrPayload = `peoyame://${direction}/${challenge}${server ? `?server=${encodeURIComponent(server)}` : ""}`;
  const qrCode = await QRCode.toDataURL(qrPayload, { errorCorrectionLevel: "M", margin: 2, width: 240 });
  return { challenge, expiresAt, qrPayload, qrCode, serverBaseUrl: server };
}

function validChallenge(value) {
  return typeof value === "string" && /^[A-Za-z0-9_-]{40,50}$/.test(value);
}

app.post("/api/auth/qr/web-challenge", async (req, res) => {
  if (!AUTH_ENABLED) return authUnavailable(res);
  try { return res.status(201).json(await createQrChallenge("web_login", null, req.body?.serverBaseUrl)); }
  catch (error) { return authFailure(res, error); }
});

app.post("/api/auth/qr/web-challenge/:challenge/approve", requireFarmer, (req, res) => {
  if (!validChallenge(req.params.challenge)) return res.status(400).json({ error: "Invalid sign-in QR code." });
  const challengeHash = farmerAuth.tokenHash(req.params.challenge);
  const challenge = cropDatabase.authChallenge(challengeHash);
  if (!challenge || challenge.purpose !== "web_login" || challenge.usedAt || Date.parse(challenge.expiresAt) <= Date.now()) {
    return res.status(410).json({ error: "This sign-in QR code has expired. Refresh it and try again." });
  }
  if (!cropDatabase.approveAuthChallenge(challengeHash, req.farmer.id)) return res.status(409).json({ error: "This sign-in request has already been approved." });
  res.status(202).json({ approved: true });
});

app.get("/api/auth/qr/web-challenge/:challenge", (req, res) => {
  if (!AUTH_ENABLED) return authUnavailable(res);
  if (!validChallenge(req.params.challenge)) return res.status(400).json({ error: "Invalid sign-in QR code." });
  const challengeHash = farmerAuth.tokenHash(req.params.challenge);
  const challenge = cropDatabase.authChallenge(challengeHash);
  if (!challenge || challenge.purpose !== "web_login" || Date.parse(challenge.expiresAt) <= Date.now() || challenge.usedAt) {
    return res.status(410).json({ error: "This sign-in QR code has expired or was already used." });
  }
  if (!challenge.approvedAt || !challenge.farmerId) return res.json({ status: "pending" });
  if (!cropDatabase.consumeAuthChallenge(challengeHash, "web_login")) return res.status(410).json({ error: "This sign-in QR code has expired or was already used." });
  const session = farmerAuth.issueSessionForFarmer(challenge.farmerId);
  if (!session) return res.status(404).json({ error: "The farmer account no longer exists." });
  res.json({ status: "approved", ...session });
});

app.post("/api/auth/qr/mobile-challenge", requireFarmer, async (req, res) => {
  try { return res.status(201).json(await createQrChallenge("mobile_login", req.farmer.id, req.body?.serverBaseUrl)); }
  catch (error) { return authFailure(res, error); }
});

app.post("/api/auth/qr/mobile-exchange", (req, res) => {
  if (!AUTH_ENABLED) return authUnavailable(res);
  const challengeValue = req.body?.challenge;
  if (!validChallenge(challengeValue)) return res.status(400).json({ error: "Invalid sign-in QR code." });
  const challengeHash = farmerAuth.tokenHash(challengeValue);
  const challenge = cropDatabase.authChallenge(challengeHash);
  if (!challenge || challenge.purpose !== "mobile_login" || Date.parse(challenge.expiresAt) <= Date.now() || challenge.usedAt) {
    return res.status(410).json({ error: "This sign-in QR code has expired or was already used." });
  }
  if (!cropDatabase.consumeAuthChallenge(challengeHash, "mobile_login")) return res.status(410).json({ error: "This sign-in QR code has expired or was already used." });
  const session = farmerAuth.issueSessionForFarmer(challenge.farmerId);
  if (!session) return res.status(404).json({ error: "The farmer account no longer exists." });
  res.json(session);
});

app.get("/api/account/authenticator", requireFarmer, (req, res) => {
  res.json({ enabled: Boolean(cropDatabase.authenticatorForFarmer(req.farmer.id)) });
});

app.post("/api/account/authenticator/setup", requireFarmer, (req, res) => {
  const secret = encodeBase32(crypto.randomBytes(20));
  cropDatabase.setAuthenticatorSecret(req.farmer.id, secret);
  const label = encodeURIComponent(`Peo Yame:${req.farmer.phone}`);
  const issuer = encodeURIComponent("Peo Yame");
  res.json({ secret, otpauthUrl: `otpauth://totp/${label}?secret=${secret}&issuer=${issuer}&algorithm=SHA1&digits=6&period=30` });
});

app.post("/api/account/authenticator/enable", requireFarmer, (req, res) => {
  const secret = cropDatabase.authenticatorForFarmer(req.farmer.id, true);
  if (!secret) return res.status(409).json({ error: "Start authenticator setup first." });
  if (!verifyAuthenticatorCode(secret, req.body?.code)) return res.status(400).json({ error: "That code is incorrect or has expired. Try the current code." });
  cropDatabase.enableAuthenticator(req.farmer.id);
  broadcastUpdate("account");
  res.json({ enabled: true });
});

app.post("/api/account/authenticator/disable", requireFarmer, (req, res) => {
  const secret = cropDatabase.authenticatorForFarmer(req.farmer.id);
  if (!secret) return res.status(409).json({ error: "Authenticator sign-in is not enabled." });
  if (!verifyAuthenticatorCode(secret, req.body?.code)) return res.status(400).json({ error: "That code is incorrect or has expired." });
  cropDatabase.disableAuthenticator(req.farmer.id);
  broadcastUpdate("account");
  res.json({ enabled: false });
});

app.get("/api/account", optionalFarmer, (req, res) => {
  if (req.farmer) return res.json(req.farmer);
  if (process.env.NODE_ENV !== "production") {
    return res.json({ id: "demo", name: "Mr Lesego Lefoko", email: "LLefoko@email.co.bw", phone: "" });
  }
  return res.status(401).json({ error: "Sign in to view this account." });
});

app.patch("/api/account", requireFarmer, (req, res) => {
  const name = String(req.body?.name || "").trim().replace(/\s+/g, " ");
  if (name.length < 2 || name.length > 80) return res.status(400).json({ error: "Enter your name (2 to 80 characters)." });
  try {
    const email = req.body?.email == null ? req.farmer.email : String(req.body.email).trim();
    const updated = cropDatabase.updateFarmer(req.farmer.id, { name, email });
    broadcastUpdate("account");
    return res.json(updated);
  } catch (error) { return authFailure(res, error); }
});

app.get("/api/farmer/crops", requireFarmer, (req, res) => res.json(cropDatabase.farmerSites(req.farmer.id)));

app.post("/api/farmer/crops", requireFarmer, (req, res) => {
  const commodity = typeof req.body?.commodity === "string" ? req.body.commodity.trim() : "";
  const label = typeof req.body?.label === "string" ? req.body.label.trim().replace(/\s+/g, " ") : "";
  if (!commodity || label.length < 2 || label.length > 80) return res.status(400).json({ error: "Choose a crop and enter a location name (2 to 80 characters)." });
  try {
    const site = cropDatabase.addFarmerSite(req.farmer.id, commodity, label);
    if (!site) return res.status(400).json({ error: "Choose a crop from the catalog." });
    broadcastUpdate("account");
    return res.status(201).json(site);
  } catch (error) { return authFailure(res, error); }
});

app.delete("/api/farmer/crops/:id", requireFarmer, (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isSafeInteger(id) || id < 1) return res.status(400).json({ error: "Invalid crop location." });
  if (!cropDatabase.deleteFarmerSite(req.farmer.id, id)) return res.status(404).json({ error: "Crop location not found." });
  broadcastUpdate("account");
  res.json({ ok: true });
});

app.get("/api/farmer/available-sensors", requireFarmer, (_req, res) => res.json(cropDatabase.availableFarmerSensors()));
app.get("/api/farmer/sensors", requireFarmer, (req, res) => res.json(cropDatabase.farmerSensors(req.farmer.id)));

app.post("/api/farmer/sensors", requireFarmer, (req, res) => {
  const sensorId = typeof req.body?.sensorId === "string" ? req.body.sensorId.trim() : "";
  const siteId = req.body?.siteId == null || req.body.siteId === "" ? null : Number(req.body.siteId);
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]{1,63}$/.test(sensorId) || (siteId != null && (!Number.isSafeInteger(siteId) || siteId < 1))) {
    return res.status(400).json({ error: "Enter a valid sensor ID and storage location." });
  }
  try {
    const linked = cropDatabase.linkFarmerSensor(req.farmer.id, sensorId, siteId);
    if (linked === null) return res.status(404).json({ error: "Crop location not found." });
    if (!linked) return res.status(404).json({ error: "No readings have been received from that sensor ID." });
    broadcastUpdate("account");
    return res.status(201).json({ ok: true });
  } catch (error) { return authFailure(res, error); }
});

app.delete("/api/farmer/sensors/:sensorId", requireFarmer, (req, res) => {
  const sensorId = String(req.params.sensorId || "");
  if (!cropDatabase.unlinkFarmerSensor(req.farmer.id, sensorId)) return res.status(404).json({ error: "Linked sensor not found." });
  broadcastUpdate("account");
  res.json({ ok: true });
});

app.get("/api/events", (req, res) => {
  res.status(200);
  res.set({
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
    "X-Accel-Buffering": "no",
  });
  res.flushHeaders?.();
  res.write(`event: connected\ndata: ${JSON.stringify({ time: new Date().toISOString() })}\n\n`);
  eventClients.add(res);
  res.on("close", () => eventClients.delete(res));
});

setInterval(() => {
  for (const client of eventClients) {
    try {
      client.write(": keepalive\n\n");
    } catch (_) {
      eventClients.delete(client);
    }
  }
}, 15000);

app.get("/api/actions", (req, res) => {
  const requested = Number.parseInt(req.query.limit, 10);
  const limit = Math.min(Math.max(requested || 500, 1), MAX_ACTIONS);
  res.json(actions.slice(-limit).reverse());
});

app.post("/api/actions", (req, res) => {
  const { action, source, actor, details } = req.body || {};
  if (typeof action !== "string" || !action.trim() || action.length > 120) {
    return res.status(400).json({ error: "action must be a non-empty string of at most 120 characters" });
  }
  const safeDetails = details && typeof details === "object" && !Array.isArray(details)
    ? details
    : {};
  const entry = logAction(action.trim(), {
    source: typeof source === "string" ? source.slice(0, 30) : "client",
    actor: typeof actor === "string" ? actor.slice(0, 80) : "Olerato.M",
    details: safeDetails,
  });
  res.status(201).json(entry);
});

app.get("/api/actions/export.md", (req, res) => {
  logAction("Exported Markdown activity log", {
    source: typeof req.query.source === "string" ? req.query.source : "api",
  });
  const requested = Number.parseInt(req.query.limit, 10);
  const limit = Math.min(Math.max(requested || MAX_ACTIONS, 1), MAX_ACTIONS);
  const selected = actions.slice(-limit);
  const rows = selected.map((item) => [
    markdownCell(item.timestamp),
    markdownCell(item.actor),
    markdownCell(item.source),
    markdownCell(item.action),
    markdownCell(JSON.stringify(item.details || {})),
  ].join(" | "));
  const markdown = [
    "# Peo Yame Activity Log",
    "",
    `Exported: ${new Date().toISOString()}`,
    `Entries: ${selected.length}`,
    "",
    "| Time (UTC) | User | Source | Action | Details |",
    "|---|---|---|---|---|",
    ...rows.map((row) => `| ${row} |`),
    "",
  ].join("\n");
  res.type("text/markdown");
  res.set("Content-Disposition", 'attachment; filename="peo-yame-actions.md"');
  res.send(markdown);
});

// Sensor gateway endpoint. A single storage bay has one active harvest, so
// incoming readings are checked against the crop currently selected in the app.
app.post("/api/readings", (req, res) => {
  const { temperature, humidity, site = "default", commodity } = req.body || {};
  if (
    typeof temperature !== "number" ||
    !Number.isFinite(temperature) ||
    typeof humidity !== "number" ||
    !Number.isFinite(humidity) ||
    humidity < 0 || humidity > 100
  ) {
    return res.status(400).json({
      error: "temperature and humidity must be finite numbers, with humidity between 0 and 100",
    });
  }
  if (typeof site !== "string" || !site.trim()) {
    return res.status(400).json({ error: "site must be a non-empty string" });
  }
  if (commodity !== undefined) {
    const requested = typeof commodity === "string"
      ? Object.keys(thresholds).find((name) => name.toLowerCase() === commodity.trim().toLowerCase())
      : undefined;
    if (!requested) {
      return res.status(400).json({ error: "commodity must be Maize or Tomato" });
    }
    if (requested !== threshold.commodity) {
      return res.status(409).json({
        error: `Active harvest is ${threshold.commodity}; select ${requested} in the app before sending its readings.`,
      });
    }
  }

  const reading = recordReading(temperature, humidity, site.trim(), "sensor");
  const alert = alerts.find((item) => item.readingId === reading.id) || null;
  logAction("Sensor reading received", {
    source: "sensor",
    details: { site: site.trim(), commodity: threshold.commodity, temperature: reading.temperature, humidity: reading.humidity },
  });
  res.status(201).json({ reading, threshold, alert });
});

// Recent sensor history; oldest first for chart consumers.
app.get("/api/readings", (req, res) => {
  const parsedLimit = Number.parseInt(req.query.limit, 10);
  const limit = Math.min(Math.max(parsedLimit || 60, 1), 200);
  const crop = typeof req.query.commodity === "string"
    ? req.query.commodity.trim().toLowerCase()
    : null;
  const matches = crop
    ? readings.filter((reading) => reading.commodity.toLowerCase() === crop)
    : readings;
  res.json(matches.slice(-limit));
});

app.get("/api/readings/export.csv", (req, res) => {
  logAction("Exported sensor data as CSV", {
    source: typeof req.query.source === "string" ? req.query.source : "api",
    details: { records: readings.length, format: "CSV" },
  });
  const columns = [
    "reading_id", "timestamp_utc", "site", "harvest", "data_source",
    "temperature_c", "humidity_pct", "min_temperature_c", "max_temperature_c",
    "min_humidity_pct", "max_humidity_pct", "threshold_breach",
  ];
  const rows = readings.map((reading) => {
    const limits = thresholds[reading.commodity];
    const breached = reading.temperature < limits.minTemp ||
      reading.temperature > limits.maxTemp ||
      reading.humidity < limits.minHumidity ||
      reading.humidity > limits.maxHumidity;
    return [
      csvCell(reading.id),
      csvCell(reading.recordedAt),
      csvCell(reading.site, true),
      csvCell(reading.commodity, true),
      csvCell(reading.dataSource || "simulation", true),
      csvCell(reading.temperature),
      csvCell(reading.humidity),
      csvCell(limits.minTemp),
      csvCell(limits.maxTemp),
      csvCell(limits.minHumidity),
      csvCell(limits.maxHumidity),
      csvCell(breached),
    ].join(",");
  });
  const csv = `\uFEFF${[columns.map((value) => csvCell(value)).join(","), ...rows].join("\r\n")}\r\n`;
  res.type("text/csv; charset=utf-8");
  res.set("Content-Disposition", 'attachment; filename="peo-yame-readings.csv"');
  res.send(csv);
});

app.get("/api/readings/latest", (req, res) => {
  const crop = typeof req.query.commodity === "string"
    ? req.query.commodity.trim().toLowerCase()
    : null;
  const matches = crop
    ? readings.filter((reading) => reading.commodity.toLowerCase() === crop)
    : readings;
  res.json(matches[matches.length - 1] || null);
});

app.get("/api/readings/history", (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  res.json(readings.filter((reading) => reading.commodity === threshold.commodity).slice(-limit));
});

app.get("/api/readings/trends", (req, res) => {
  const ranges = { "24h": 24, month: 24 * 30, "3months": 24 * 90 };
  const hours = ranges[req.query.range] || ranges["24h"];
  const since = Date.now() - hours * 60 * 60 * 1000;
  const points = trendBuckets
    .filter((bucket) => bucket.commodity === threshold.commodity && Date.parse(`${bucket.minute}:00Z`) >= since)
    .map((bucket) => ({
      recordedAt: `${bucket.minute}:00Z`,
      temperature: Math.round((bucket.temperatureTotal / bucket.count) * 10) / 10,
      humidity: Math.round((bucket.humidityTotal / bucket.count) * 10) / 10,
      count: bucket.count,
      synthetic: bucket.syntheticCount > 0,
      live: bucket.liveCount > 0,
    }));
  res.json({
    range: req.query.range || "24h",
    includesSyntheticBaseline: points.some((point) => point.synthetic),
    points,
  });
});

app.get("/api/crops", (req, res) => res.json(cropDatabase.listCrops()));

app.post("/api/crops", (req, res) => {
  const body = req.body || {};
  const name = typeof body.name === "string" ? body.name.trim() : "";
  const values = [body.minTemp, body.maxTemp, body.minHumidity, body.maxHumidity];
  if (!name || name.length > 60 || /[<>]/.test(name) || values.some((value) => typeof value !== "number" || !Number.isFinite(value))) {
    return res.status(400).json({ error: "Enter a crop name and numeric temperature and humidity limits." });
  }
  const [minTemp, maxTemp, minHumidity, maxHumidity] = values;
  if (minTemp < -50 || maxTemp > 100 || minTemp >= maxTemp || minHumidity < 0 || maxHumidity > 100 || minHumidity >= maxHumidity) {
    return res.status(400).json({ error: "Use temperature limits between -50 and 100°C and humidity limits between 0 and 100%, with each minimum below its maximum." });
  }
  try {
    const crop = cropDatabase.addCrop({ commodity: name, minTemp, maxTemp, minHumidity, maxHumidity });
    thresholds[crop.commodity] = crop;
    broadcastUpdate("crops");
    logAction("Added crop", { source: "api", details: { crop: crop.commodity } });
    return res.status(201).json(crop);
  } catch (error) {
    if (`${error.message || error} ${error.stderr?.toString() || ""}`.includes("UNIQUE constraint failed")) return res.status(409).json({ error: "A crop with that name already exists." });
    return res.status(500).json({ error: "Could not save this crop." });
  }
});

app.get("/api/thresholds", (req, res) => {
  res.json(threshold);
});

app.post("/api/commodity", (req, res) => {
  const name = typeof req.body?.name === "string" ? req.body.name.trim() : "";
  const selected = cropDatabase.getCrop(name);
  if (!selected) {
    return res.status(400).json({
      error: `Choose a crop saved in your harvest list: ${cropDatabase.listCrops().map((crop) => crop.commodity).join(", ")}.`,
    });
  }

  const previousCommodity = threshold.commodity;
  threshold = selected;
  cropDatabase.setActiveCrop(name);
  broadcastUpdate("selection");
  logAction("Harvest changed", {
    source: typeof req.body?.source === "string" ? req.body.source : "api",
    details: { from: previousCommodity, to: name },
  });
  // Re-seed the chart around the newly selected crop and record an immediate,
  // in-range reading so the dashboard updates without waiting for the timer.
  const reading = process.env.NODE_ENV === "production"
    ? readings.filter((item) => item.commodity === name).at(-1) || null
    : generateSafeReading();
  res.json({ threshold, reading });
});

app.get("/api/alerts", (req, res) => {
  const parsedLimit = Number.parseInt(req.query.limit, 10);
  const limit = Math.min(Math.max(parsedLimit || 50, 1), 200);
  const selected = req.query.unacknowledged === "true"
    ? alerts.filter((alert) => !alert.acknowledged)
    : alerts;
  res.json(selected.slice(0, limit));
});

app.post("/api/alerts/:id/acknowledge", (req, res) => {
  const alert = alerts.find((item) => item.id === Number.parseInt(req.params.id, 10));
  if (!alert) return res.status(404).json({ error: "Alert not found" });
  alert.acknowledged = true;
  broadcastUpdate("alerts");
  logAction("Alert acknowledged", { details: { alertId: alert.id, commodity: alert.commodity } });
  res.json(alert);
});

app.get("/api/sms-log", (req, res) => {
  res.json(smsLog);
});

app.get("/api/incidents", (req, res) => {
  res.json(incidents);
});

app.post("/api/incidents", (req, res) => {
  const {
    incident_date: incidentDate,
    commodity,
    breach_description: breachDescription,
    duration = null,
    outcome,
  } = req.body || {};
  const crop = typeof commodity === "string"
    ? Object.keys(thresholds).find((name) => name.toLowerCase() === commodity.trim().toLowerCase())
    : undefined;
  if (!incidentDate || !crop || !breachDescription || !["loss", "noloss"].includes(outcome)) {
    return res.status(400).json({
      error: "incident_date, a supported commodity, breach_description, and outcome (loss or noloss) are required",
    });
  }

  const incident = {
    id: nextIncidentId++,
    incident_date: String(incidentDate),
    commodity: crop,
    breach_description: String(breachDescription),
    duration: duration == null ? null : String(duration),
    outcome,
    created_at: new Date().toISOString(),
  };
  incidents.unshift(incident);
  logAction("Incident recorded", { details: { incidentId: incident.id, commodity: crop, outcome } });
  res.status(201).json(incident);
});

// Hold the injected breach as the latest reading long enough for the phone demo.
app.post("/api/sim/breach", (req, res) => {
  demoBreachActive = true;
  clearTimeout(demoBreachTimeout);
  demoBreachTimeout = setTimeout(() => {
    demoBreachActive = false;
    demoBreachTimeout = undefined;
  }, 15000);

  const severityFactors = [0.15, 0.5, 1, 1.6];
  const severity = severityFactors[demoBreachCount++ % severityFactors.length];
  const tempRange = threshold.maxTemp - threshold.minTemp;
  const temperature = Math.min(100, threshold.maxTemp + tempRange * severity);
  const humidity = (threshold.minHumidity + threshold.maxHumidity) / 2;
  const reading = recordReading(temperature, humidity);
  logAction("Demo breach triggered", {
    source: typeof req.body?.source === "string" ? req.body.source : "api",
    details: { commodity: threshold.commodity, readingId: reading.id, severity },
  });
  res.status(201).json({ reading, alert: alerts[0] });
});

app.listen(PORT, HOST, () => {
  logAction("Backend started", { source: "system", details: { port: PORT } });
  console.log(`Storage monitor API running on http://${HOST}:${PORT} (${process.env.NODE_ENV || "development"})`);
});
