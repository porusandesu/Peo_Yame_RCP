// routes/readings.js
// Sensor data ingestion + retrieval.
//
// POST /api/readings   <- this is the endpoint the Arduino/GSM module (or,
//                         for now, simulate-sensor.js) calls every time it
//                         takes a reading.
// GET  /api/readings         -> recent readings (for the dashboard chart)
// GET  /api/readings/latest  -> most recent single reading (for the gauges)

const express = require('express');
const db = require('../db');

const router = express.Router();

function getThreshold(commodity) {
  return db.prepare('SELECT * FROM thresholds WHERE commodity = ?').get(commodity);
}

function raiseAlertIfNeeded(reading, threshold) {
  if (!threshold) return null; // unknown commodity - nothing to check against

  const tempOverFrac = (reading.temperature - threshold.temp_max) / threshold.temp_max;
  const humOverFrac = (reading.humidity - threshold.hum_max) / threshold.hum_max;
  const worst = Math.max(tempOverFrac, humOverFrac);

  if (worst <= 0) return null; // within threshold

  const level = worst > 0.12 ? 'critical' : 'warning';
  const message =
    tempOverFrac >= humOverFrac
      ? `Temperature ${reading.temperature}°C exceeds ${threshold.temp_max}°C limit for ${reading.commodity}`
      : `Humidity ${reading.humidity}%RH exceeds ${threshold.hum_max}%RH limit for ${reading.commodity}`;

  const insert = db.prepare(`
    INSERT INTO alerts (reading_id, commodity, level, message)
    VALUES (?, ?, ?, ?)
  `);
  const info = insert.run(reading.id, reading.commodity, level, message);
  return db.prepare('SELECT * FROM alerts WHERE id = ?').get(info.lastInsertRowid);
}

// POST /api/readings
// Body: { site?, commodity, temperature, humidity }
router.post('/', (req, res) => {
  const { site = 'default', commodity, temperature, humidity } = req.body;

  if (!commodity || typeof temperature !== 'number' || typeof humidity !== 'number') {
    return res.status(400).json({
      error: 'commodity (string), temperature (number), and humidity (number) are required',
    });
  }

  const insert = db.prepare(`
    INSERT INTO readings (site, commodity, temperature, humidity)
    VALUES (?, ?, ?, ?)
  `);
  const info = insert.run(site, commodity, temperature, humidity);
  const reading = db.prepare('SELECT * FROM readings WHERE id = ?').get(info.lastInsertRowid);

  const threshold = getThreshold(commodity);
  const alert = raiseAlertIfNeeded(reading, threshold);

  res.status(201).json({ reading, threshold: threshold || null, alert: alert || null });
});

// GET /api/readings?commodity=tomato&limit=60
router.get('/', (req, res) => {
  const { commodity, limit = 60 } = req.query;
  const cappedLimit = Math.min(parseInt(limit, 10) || 60, 500);

  let rows;
  if (commodity) {
    rows = db
      .prepare('SELECT * FROM readings WHERE commodity = ? ORDER BY recorded_at DESC, id DESC LIMIT ?')
      .all(commodity, cappedLimit);
  } else {
    rows = db
      .prepare('SELECT * FROM readings ORDER BY recorded_at DESC, id DESC LIMIT ?')
      .all(cappedLimit);
  }

  res.json(rows.reverse()); // oldest first, ready for a time-series chart
});

// GET /api/readings/latest?commodity=tomato
router.get('/latest', (req, res) => {
  const { commodity } = req.query;

  const row = commodity
    ? db
        .prepare('SELECT * FROM readings WHERE commodity = ? ORDER BY recorded_at DESC, id DESC LIMIT 1')
        .get(commodity)
    : db.prepare('SELECT * FROM readings ORDER BY recorded_at DESC, id DESC LIMIT 1').get();

  if (!row) return res.status(404).json({ error: 'No readings recorded yet' });

  const threshold = getThreshold(row.commodity);
  res.json({ reading: row, threshold: threshold || null });
});

module.exports = router;
