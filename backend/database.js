const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

// Uses SQLite's native CLI so the backend has no downloaded native npm addon.
// User supplied strings are always SQL string literals (single quotes doubled).
const file = process.env.DATABASE_PATH || path.join(__dirname, "data", "storage-monitor.sqlite");
fs.mkdirSync(path.dirname(file), { recursive: true });
function quote(value) { return `'${String(value).replaceAll("'", "''")}'`; }
function sql(statement, asJson = false) {
  const args = asJson ? ["-json", file] : [file];
  const output = execFileSync("sqlite3", args, { input: `PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;\n${statement}\n`, encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
  return asJson && output.trim() ? JSON.parse(output) : output;
}
sql("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;");
sql(`CREATE TABLE IF NOT EXISTS crops (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE,
  min_temp REAL NOT NULL CHECK(min_temp BETWEEN -50 AND 100),
  max_temp REAL NOT NULL CHECK(max_temp BETWEEN -50 AND 100),
  min_humidity REAL NOT NULL CHECK(min_humidity BETWEEN 0 AND 100),
  max_humidity REAL NOT NULL CHECK(max_humidity BETWEEN 0 AND 100),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK(min_temp < max_temp), CHECK(min_humidity < max_humidity)
);
CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS readings (
  id INTEGER PRIMARY KEY, site TEXT NOT NULL, crop_id INTEGER NOT NULL REFERENCES crops(id),
  temperature REAL NOT NULL, humidity REAL NOT NULL CHECK(humidity BETWEEN 0 AND 100),
  data_source TEXT NOT NULL, recorded_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS readings_recorded_at_idx ON readings(recorded_at);`);

function toCrop(row) {
  return row && { id: row.id, commodity: row.name, minTemp: row.min_temp, maxTemp: row.max_temp, minHumidity: row.min_humidity, maxHumidity: row.max_humidity };
}
function findCrop(name) {
  return sql(`SELECT * FROM crops WHERE name=${quote(name)} COLLATE NOCASE LIMIT 1;`, true)[0];
}

for (const crop of [
  { commodity: "Maize", minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 70 },
  { commodity: "Tomato", minTemp: 10, maxTemp: 20, minHumidity: 85, maxHumidity: 95 },
]) {
  sql(`INSERT OR IGNORE INTO crops(name,min_temp,max_temp,min_humidity,max_humidity) VALUES(${quote(crop.commodity)},${crop.minTemp},${crop.maxTemp},${crop.minHumidity},${crop.maxHumidity});`);
}
sql("INSERT OR IGNORE INTO app_settings(key,value) VALUES('active_crop','Maize');");

module.exports = {
  listCrops: () => sql("SELECT * FROM crops ORDER BY name COLLATE NOCASE;", true).map(toCrop),
  getCrop: (name) => toCrop(findCrop(name)),
  addCrop: (crop) => {
    sql(`INSERT INTO crops(name,min_temp,max_temp,min_humidity,max_humidity) VALUES(${quote(crop.commodity)},${crop.minTemp},${crop.maxTemp},${crop.minHumidity},${crop.maxHumidity});`);
    return toCrop(findCrop(crop.commodity));
  },
  activeCropName: () => sql("SELECT value FROM app_settings WHERE key='active_crop';", true)[0]?.value || "Maize",
  setActiveCrop: (name) => sql(`INSERT INTO app_settings(key,value) VALUES('active_crop',${quote(name)}) ON CONFLICT(key) DO UPDATE SET value=excluded.value;`),
  saveReading: (reading) => {
    const crop = findCrop(reading.commodity);
    if (!crop) throw new Error("Cannot save a reading for an unknown crop");
    sql(`INSERT INTO readings(id,site,crop_id,temperature,humidity,data_source,recorded_at) VALUES(${reading.id},${quote(reading.site)},${crop.id},${reading.temperature},${reading.humidity},${quote(reading.dataSource)},${quote(reading.recordedAt)});`);
  },
  recentReadings: (limit = 200) => sql(`SELECT r.id,r.site,c.name AS commodity,r.temperature,r.humidity,r.data_source AS dataSource,r.recorded_at AS recordedAt FROM readings r JOIN crops c ON c.id=r.crop_id ORDER BY r.id DESC LIMIT ${Math.max(1, Math.min(Number(limit) || 200, 2000))};`, true).reverse(),
};
