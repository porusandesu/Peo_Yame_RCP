/**
 * Storage Monitor - Demo Backend
 * ------------------------------
 * A small local API that stands in for the real sensor pipeline while the
 * ESP32 + GSM hardware isn't built yet. It generates realistic-looking
 * temperature/humidity readings on an interval, evaluates them against a
 * threshold, and raises alerts when a reading breaches it - the exact same
 * shape the real system will eventually produce.
 *
 * TO SWITCH TO REAL DATA LATER:
 * Replace the `generateReading()` function and the in-memory arrays below
 * with real queries against your database (readings, thresholds tables).
 * The route handlers and response shapes can stay exactly the same, so the
 * Android app and dashboard don't need to change at all.
 */

const express = require("express");
const cors = require("cors");
const fs = require("node:fs");
const path = require("node:path");
const cropDatabase = require("./database");

const app = express();
const allowedOrigins = (process.env.CORS_ORIGINS || "").split(",").map((value) => value.trim()).filter(Boolean);
app.use(cors({ origin: allowedOrigins.length ? allowedOrigins : process.env.NODE_ENV === "production" ? false : true }));
app.use(express.json({ limit: "32kb" }));
app.use(express.static(path.join(__dirname, "public")));

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || (process.env.NODE_ENV === "production" ? "127.0.0.1" : "0.0.0.0");
const ACTION_LOG_PATH = path.join(__dirname, "data", "actions.jsonl");
const MAX_ACTIONS = 2500;
fs.mkdirSync(path.dirname(ACTION_LOG_PATH), { recursive: true });

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
let readings = cropDatabase.recentReadings(200);
// Keep one compact aggregate per minute so trend views can cover up to 90 days.
// A marked 24-hour synthetic baseline is added at startup to make the demo chart useful.
let trendBuckets = [];
let alerts = [];
let smsLog = [];
let incidents = [];
let nextReadingId = readings.reduce((next, item) => Math.max(next, item.id + 1), 1);
let nextAlertId = 1;
let nextIncidentId = 1;
let demoBreachActive = false;
let demoBreachTimeout;

function recordReading(temperature, humidity, site = "default", dataSource = "simulation") {
  const reading = {
    id: nextReadingId++,
    site,
    commodity: threshold.commodity,
    dataSource,
    temperature: Math.round(temperature * 10) / 10,
    humidity: Math.round(humidity * 10) / 10,
    recordedAt: new Date().toISOString(),
  };

  readings.push(reading);
  cropDatabase.saveReading(reading);
  if (readings.length > 200) readings.shift(); // keep memory bounded

  const minute = reading.recordedAt.slice(0, 16);
  let bucket = trendBuckets[trendBuckets.length - 1];
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
    ? threshold.maxHumidity + Math.random() * Math.max(5, humidityRange * 0.25)
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

function seedDemoTrendHistory() {
  const intervalMs = 15 * 60 * 1000;
  const dayMs = 24 * 60 * 60 * 1000;
  const end = Math.floor(Date.now() / intervalMs) * intervalMs;
  const start = end - dayMs;
  const temperatureMidpoint = (threshold.minTemp + threshold.maxTemp) / 2;
  const humidityMidpoint = (threshold.minHumidity + threshold.maxHumidity) / 2;
  const temperatureAmplitude = (threshold.maxTemp - threshold.minTemp) * 0.04;
  const humidityAmplitude = (threshold.maxHumidity - threshold.minHumidity) * 0.04;

  for (let timestamp = start; timestamp <= end; timestamp += intervalMs) {
    const phase = ((timestamp - start) / dayMs) * Math.PI * 2;
    // A narrow, stable crop-specific baseline within the active thresholds.
    const temperature = temperatureMidpoint + temperatureAmplitude * Math.sin(phase);
    const humidity = humidityMidpoint + humidityAmplitude * Math.sin(phase + Math.PI / 2);
    trendBuckets.push({
      minute: new Date(timestamp).toISOString().slice(0, 16),
      commodity: threshold.commodity,
      temperatureTotal: temperature,
      humidityTotal: humidity,
      count: 1,
      syntheticCount: 1,
      liveCount: 0,
    });
  }
}

// Simulate a sensor pushing a new reading every 5 seconds
if (process.env.NODE_ENV !== "production") {
  seedDemoTrendHistory();
  setInterval(() => {
    if (!demoBreachActive) generateReading();
  }, 5000);
  if (!readings.length) generateReading();
} else if (readings.length) {
  const lastCrop = readings[readings.length - 1].commodity;
  threshold = cropDatabase.getCrop(lastCrop) || threshold;
}

// ---- Routes ----

app.get("/api/status", (req, res) => {
  const latest = readings[readings.length - 1] || null;
  const breached =
    latest &&
    (latest.temperature < threshold.minTemp ||
      latest.temperature > threshold.maxTemp ||
      latest.humidity < threshold.minHumidity ||
      latest.humidity > threshold.maxHumidity);
  res.json({ latest, threshold, breached: !!breached });
});

app.get("/api/health", (req, res) => {
  res.json({ status: "ok", time: new Date().toISOString() });
});

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
  res.json(readings.slice(-limit));
});

app.get("/api/readings/trends", (req, res) => {
  const ranges = { "24h": 24, month: 24 * 30, "3months": 24 * 90 };
  const hours = ranges[req.query.range] || ranges["24h"];
  const since = Date.now() - hours * 60 * 60 * 1000;
  const points = trendBuckets
    .filter((bucket) => Date.parse(`${bucket.minute}:00Z`) >= since)
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
  logAction("Harvest changed", {
    source: typeof req.body?.source === "string" ? req.body.source : "api",
    details: { from: previousCommodity, to: name },
  });
  // Re-seed the chart around the newly selected crop and record an immediate,
  // in-range reading so the dashboard updates without waiting for the timer.
  trendBuckets = [];
  if (process.env.NODE_ENV !== "production") seedDemoTrendHistory();
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

  const reading = recordReading(threshold.maxTemp + 5.4, threshold.maxHumidity + 8.2);
  logAction("Demo breach triggered", {
    source: typeof req.body?.source === "string" ? req.body.source : "api",
    details: { commodity: threshold.commodity, readingId: reading.id },
  });
  res.status(201).json({ reading, alert: alerts[0] });
});

app.listen(PORT, HOST, () => {
  logAction("Backend started", { source: "system", details: { port: PORT } });
  console.log(`Storage monitor API running on http://${HOST}:${PORT} (${process.env.NODE_ENV || "development"})`);
});
