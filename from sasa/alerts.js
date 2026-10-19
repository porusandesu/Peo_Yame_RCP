// routes/alerts.js
// Alerts are created automatically by routes/readings.js whenever an
// incoming reading breaches its commodity's threshold. This route just
// lets the dashboard list them and mark them as handled.

const express = require('express');
const db = require('../db');

const router = express.Router();

// GET /api/alerts?limit=20&unacknowledged=true
router.get('/', (req, res) => {
  const { limit = 20, unacknowledged } = req.query;
  const cappedLimit = Math.min(parseInt(limit, 10) || 20, 200);

  let rows;
  if (unacknowledged === 'true') {
    rows = db
      .prepare('SELECT * FROM alerts WHERE acknowledged = 0 ORDER BY created_at DESC LIMIT ?')
      .all(cappedLimit);
  } else {
    rows = db.prepare('SELECT * FROM alerts ORDER BY created_at DESC LIMIT ?').all(cappedLimit);
  }

  res.json(rows);
});

// POST /api/alerts/:id/acknowledge
router.post('/:id/acknowledge', (req, res) => {
  const info = db.prepare('UPDATE alerts SET acknowledged = 1 WHERE id = ?').run(req.params.id);
  if (info.changes === 0) return res.status(404).json({ error: 'Alert not found' });
  res.json(db.prepare('SELECT * FROM alerts WHERE id = ?').get(req.params.id));
});

module.exports = router;
