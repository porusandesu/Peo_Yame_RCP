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
const path = require("node:path");

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

const PORT = 3000;

// ---- Config: mirrors your ER diagram's THRESHOLD table ----
const thresholds = {
  Maize: {
    commodity: "Maize",
    minTemp: 10,
    maxTemp: 27,
    minHumidity: 30,
    maxHumidity: 70,
  },
  Tomato: {
    commodity: "Tomato",
    minTemp: 10,
    maxTemp: 20,
    minHumidity: 85,
    maxHumidity: 95,
  },
};
let threshold = thresholds.Maize;

// ---- In-memory "database" (swap for real DB queries later) ----
let readings = [];
// Keep one compact aggregate per minute so trend views can cover up to 90 days.
// A marked 24-hour synthetic baseline is added at startup to make the demo chart useful.
let trendBuckets = [];
let alerts = [];
let smsLog = [];
let incidents = [];
let nextReadingId = 1;
let nextAlertId = 1;
let nextIncidentId = 1;
let demoBreachActive = false;
let demoBreachTimeout;

function recordReading(temperature, humidity, site = "default") {
  const reading = {
    id: nextReadingId++,
    site,
    commodity: threshold.commodity,
    temperature: Math.round(temperature * 10) / 10,
    humidity: Math.round(humidity * 10) / 10,
    recordedAt: new Date().toISOString(),
  };

  readings.push(reading);
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
seedDemoTrendHistory();
setInterval(() => {
  if (!demoBreachActive) generateReading();
}, 5000);
generateReading(); // seed one immediately on boot

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

  const reading = recordReading(temperature, humidity, site.trim());
  const alert = alerts.find((item) => item.readingId === reading.id) || null;
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
    includesSyntheticBaseline: true,
    points,
  });
});

app.get("/api/thresholds", (req, res) => {
  res.json(threshold);
});

app.post("/api/commodity", (req, res) => {
  const name = typeof req.body?.name === "string" ? req.body.name.trim() : "";
  if (!Object.hasOwn(thresholds, name)) {
    return res.status(400).json({
      error: `Unsupported harvest. Choose one of: ${Object.keys(thresholds).join(", ")}.`,
    });
  }

  threshold = thresholds[name];
  // Re-seed the chart around the newly selected crop and record an immediate,
  // in-range reading so the dashboard updates without waiting for the timer.
  trendBuckets = [];
  seedDemoTrendHistory();
  const reading = generateSafeReading();
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
  res.status(201).json({ reading, alert: alerts[0] });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Storage monitor demo API running on http://0.0.0.0:${PORT}`);
  console.log(`On your phone/emulator, use your laptop's LAN IP, e.g. http://192.168.x.x:${PORT}`);
});
