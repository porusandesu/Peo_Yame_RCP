// db.js
// Database setup for the storage monitoring system.
//
// Uses SQLite (via better-sqlite3) so the prototype runs with zero external
// setup - no database server to install. The schema is plain SQL, so moving
// to PostgreSQL or MySQL later (as mentioned in the proposal) mainly means
// swapping this file for a client of that database; the rest of the app
// (routes/*.js) only calls the functions exported here.

const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'storage_monitor.db');
const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');

db.exec(`
  CREATE TABLE IF NOT EXISTS readings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    site TEXT NOT NULL DEFAULT 'default',
    commodity TEXT NOT NULL,
    temperature REAL NOT NULL,
    humidity REAL NOT NULL,
    recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE INDEX IF NOT EXISTS idx_readings_commodity_time
    ON readings (commodity, recorded_at DESC);

  CREATE TABLE IF NOT EXISTS thresholds (
    commodity TEXT PRIMARY KEY,
    temp_max REAL NOT NULL,
    hum_max REAL NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reading_id INTEGER REFERENCES readings(id),
    commodity TEXT NOT NULL,
    level TEXT NOT NULL CHECK (level IN ('warning','critical')),
    message TEXT NOT NULL,
    acknowledged INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_date TEXT NOT NULL,
    commodity TEXT NOT NULL,
    breach_description TEXT NOT NULL,
    duration TEXT,
    outcome TEXT NOT NULL CHECK (outcome IN ('loss','noloss')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
`);

// Seed a few sensible default thresholds if the table is empty, so the API
// is useful immediately without a manual setup step.
const thresholdCount = db.prepare('SELECT COUNT(*) AS n FROM thresholds').get().n;
if (thresholdCount === 0) {
  const seed = db.prepare(
    'INSERT INTO thresholds (commodity, temp_max, hum_max) VALUES (?, ?, ?)'
  );
  const seedMany = db.transaction((rows) => {
    for (const r of rows) seed.run(r.commodity, r.temp_max, r.hum_max);
  });
  seedMany([
    { commodity: 'tomato', temp_max: 13, hum_max: 90 },
    { commodity: 'leafy', temp_max: 4, hum_max: 95 },
    { commodity: 'maize', temp_max: 25, hum_max: 70 },
  ]);
}

module.exports = db;
