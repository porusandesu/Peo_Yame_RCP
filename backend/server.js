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
const threshold = {
  commodity: "Maize",
  minTemp: 10,
  maxTemp: 27,
  minHumidity: 30,
  maxHumidity: 70,
};

// ---- In-memory "database" (swap for real DB queries later) ----
let readings = [];
// Keep one compact aggregate per minute so trend views can cover up to 90 days.
// Only data collected since this demo server started is shown; no history is invented.
let trendBuckets = [];
let alerts = [];
let smsLog = [];
let nextReadingId = 1;
let nextAlertId = 1;
let demoBreachActive = false;
let demoBreachTimeout;

function recordReading(temperature, humidity) {
  const reading = {
    id: nextReadingId++,
    temperature: Math.round(temperature * 10) / 10,
    humidity: Math.round(humidity * 10) / 10,
    recordedAt: new Date().toISOString(),
  };

  readings.push(reading);
  if (readings.length > 200) readings.shift(); // keep memory bounded

  const minute = reading.recordedAt.slice(0, 16);
  let bucket = trendBuckets[trendBuckets.length - 1];
  if (!bucket || bucket.minute !== minute) {
    bucket = { minute, temperatureTotal: 0, humidityTotal: 0, count: 0 };
    trendBuckets.push(bucket);
  }
  bucket.temperatureTotal += reading.temperature;
  bucket.humidityTotal += reading.humidity;
  bucket.count += 1;
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
      message: `Threshold breached: ${reading.temperature}\u00b0C, ${reading.humidity}% RH`,
      sentAt,
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
  const temperature = spike
    ? threshold.maxTemp + Math.random() * 5
    : 18 + Math.random() * 6;
  const humidity = spike
    ? threshold.maxHumidity + Math.random() * 10
    : 45 + Math.random() * 15;

  return recordReading(temperature, humidity);
}

// Simulate a sensor pushing a new reading every 5 seconds
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

app.get("/api/readings/latest", (req, res) => {
  res.json(readings[readings.length - 1] || null);
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
    }));
  res.json({ range: req.query.range || "24h", points });
});

app.get("/api/thresholds", (req, res) => {
  res.json(threshold);
});

app.get("/api/alerts", (req, res) => {
  res.json(alerts);
});

app.get("/api/sms-log", (req, res) => {
  res.json(smsLog);
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
