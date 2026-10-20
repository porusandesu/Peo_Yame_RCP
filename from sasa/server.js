// server.js
// Entry point for the storage monitoring backend.
//
// This is the service the proposal (section 1.8) describes as the
// "back-end service: handling sensor data ingestion, threshold logic, and
// alert dispatch". Run it, then point the dashboard's fetch calls (or
// simulate-sensor.js, while there's no hardware yet) at it.

require('dotenv').config();
const express = require('express');
const cors = require('cors');

const readingsRouter = require('./routes/readings');
const thresholdsRouter = require('./routes/thresholds');
const alertsRouter = require('./routes/alerts');
const incidentsRouter = require('./routes/incidents');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors()); // allows the dashboard (served from a different origin/file) to call this API
app.use(express.json());

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

app.use('/api/readings', readingsRouter);
app.use('/api/thresholds', thresholdsRouter);
app.use('/api/alerts', alertsRouter);
app.use('/api/incidents', incidentsRouter);

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Storage monitor backend listening on http://localhost:${PORT}`);
});
