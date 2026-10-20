// routes/incidents.js
// The historical log linking storage conditions to spoilage/loss outcomes,
// as called for in the proposal's scope (1.7) - lets staff record what
// actually happened after a breach, so patterns can be reviewed later.

const express = require('express');
const db = require('../db');

const router = express.Router();

// GET /api/incidents
router.get('/', (req, res) => {
  const rows = db.prepare('SELECT * FROM incidents ORDER BY created_at DESC').all();
  res.json(rows);
});

// POST /api/incidents
// Body: { incident_date, commodity, breach_description, duration?, outcome }
router.post('/', (req, res) => {
  const { incident_date, commodity, breach_description, duration = null, outcome } = req.body;

  if (!incident_date || !commodity || !breach_description || !outcome) {
    return res.status(400).json({
      error: 'incident_date, commodity, breach_description, and outcome are required',
    });
  }
  if (!['loss', 'noloss'].includes(outcome)) {
    return res.status(400).json({ error: "outcome must be 'loss' or 'noloss'" });
  }

  const info = db.prepare(`
    INSERT INTO incidents (incident_date, commodity, breach_description, duration, outcome)
    VALUES (?, ?, ?, ?, ?)
  `).run(incident_date, commodity, breach_description, duration, outcome);

  res.status(201).json(db.prepare('SELECT * FROM incidents WHERE id = ?').get(info.lastInsertRowid));
});

module.exports = router;
