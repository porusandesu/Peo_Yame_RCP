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

const app = express();
app.use(cors());
app.use(express.json());

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
let alerts = [];
let nextReadingId = 1;
let nextAlertId = 1;

function generateReading() {
  // Randomly drifts around a baseline, occasionally spikes to trigger an alert
  const spike = Math.random() < 0.15;
  const temperature = spike
    ? threshold.maxTemp + Math.random() * 5
    : 18 + Math.random() * 6;
  const humidity = spike
    ? threshold.maxHumidity + Math.random() * 10
    : 45 + Math.random() * 15;

  const reading = {
    id: nextReadingId++,
    temperature: Math.round(temperature * 10) / 10,
    humidity: Math.round(humidity * 10) / 10,
    recordedAt: new Date().toISOString(),
  };

  readings.push(reading);
  if (readings.length > 200) readings.shift(); // keep memory bounded

  const breached =
    reading.temperature < threshold.minTemp ||
    reading.temperature > threshold.maxTemp ||
    reading.humidity < threshold.minHumidity ||
    reading.humidity > threshold.maxHumidity;

  if (breached) {
    alerts.unshift({
      id: nextAlertId++,
      readingId: reading.id,
      message: `Threshold breached: ${reading.temperature}\u00b0C, ${reading.humidity}% RH`,
      sentAt: new Date().toISOString(),
    });
    if (alerts.length > 50) alerts.pop();
  }

  return reading;
}

// Simulate a sensor pushing a new reading every 5 seconds
setInterval(generateReading, 5000);
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

app.get("/api/thresholds", (req, res) => {
  res.json(threshold);
});

app.get("/api/alerts", (req, res) => {
  res.json(alerts);
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Storage monitor demo API running on http://0.0.0.0:${PORT}`);
  console.log(`On your phone/emulator, use your laptop's LAN IP, e.g. http://192.168.x.x:${PORT}`);
});
