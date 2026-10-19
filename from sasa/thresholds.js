// routes/thresholds.js
// Configurable spoilage-risk thresholds per commodity type.

const express = require('express');
const db = require('../db');

const router = express.Router();

// GET /api/thresholds
router.get('/', (req, res) => {
  const rows = db.prepare('SELECT * FROM thresholds ORDER BY commodity').all();
  res.json(rows);
});

// POST /api/thresholds
// Body: { commodity, temp_max, hum_max }
// Creates the commodity's thresholds if new, or updates them if it exists.
router.post('/', (req, res) => {
  const { commodity, temp_max, hum_max } = req.body;

  if (!commodity || typeof temp_max !== 'number' || typeof hum_max !== 'number') {
    return res.status(400).json({
      error: 'commodity (string), temp_max (number), and hum_max (number) are required',
    });
  }

  db.prepare(`
    INSERT INTO thresholds (commodity, temp_max, hum_max, updated_at)
    VALUES (?, ?, ?, datetime('now'))
    ON CONFLICT(commodity) DO UPDATE SET
      temp_max = excluded.temp_max,
      hum_max = excluded.hum_max,
      updated_at = excluded.updated_at
  `).run(commodity, temp_max, hum_max);

  const row = db.prepare('SELECT * FROM thresholds WHERE commodity = ?').get(commodity);
  res.json(row);
});

module.exports = router;
