const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

// Packaged Windows builds embed sqlite3.exe and extract it to the OS temp
// directory on first use. Source runs continue to use sqlite3 from PATH.
let sqliteCommand = process.env.SQLITE3_PATH || "sqlite3";
if (process.pkg) {
  sqliteCommand = path.join(os.tmpdir(), "peo-yame-sqlite3.exe");
  if (!fs.existsSync(sqliteCommand)) {
    fs.writeFileSync(sqliteCommand, fs.readFileSync(path.join(__dirname, "vendor", "sqlite3.exe")));
  }
}

// Keep portable-build data beside the EXE. Source runs keep their data in
// backend/data; DATABASE_PATH can override either location.
const appDirectory = process.pkg ? path.dirname(process.execPath) : __dirname;
const dataDirectory = process.env.APP_DATA_DIR || path.join(appDirectory, "data");
const file = process.env.DATABASE_PATH || path.join(dataDirectory, "storage-monitor.sqlite");
fs.mkdirSync(path.dirname(file), { recursive: true });
function quote(value) { return `'${String(value).replaceAll("'", "''")}'`; }
function sql(statement, asJson = false) {
  const args = asJson ? ["-json", file] : [file];
  // Set the CLI timeout with its dot command. `PRAGMA busy_timeout` returns a
  // result row, which would otherwise be concatenated with SELECT results in
  // `-json` mode and make the combined output invalid JSON.
  const output = execFileSync(sqliteCommand, args, { input: `.timeout 5000\nPRAGMA foreign_keys=ON;\n${statement}\n`, encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
  // sqlite3 emits no output (rather than `[]`) for a JSON query with no rows.
  return asJson ? (output.trim() ? JSON.parse(output) : []) : output;
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

function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6D2B79F5) >>> 0;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function seedDemoHistory() {
  const marker = sql("SELECT value FROM app_settings WHERE key='demo_history_seed_v1';", true)[0];
  if (marker) return;

  const crops = sql("SELECT * FROM crops ORDER BY id;", true);
  const nextId = Number(sql("SELECT COALESCE(MAX(id),0)+1 AS next_id FROM readings;", true)[0].next_id);
  const intervalMs = 60 * 60 * 1000;
  const end = Math.floor(Date.now() / intervalMs) * intervalMs;
  const start = end - 90 * 24 * intervalMs;
  const rows = [];
  let id = nextId;

  for (let timestamp = start, hour = 0; timestamp <= end; timestamp += intervalMs, hour++) {
    for (const crop of crops) {
      const random = seededRandom((crop.id * 0x9E3779B1) ^ hour);
      const temperatureRange = crop.max_temp - crop.min_temp;
      const humidityRange = crop.max_humidity - crop.min_humidity;
      let temperature = (crop.min_temp + crop.max_temp) / 2 + (random() - 0.5) * temperatureRange * 0.3;
      let humidity = (crop.min_humidity + crop.max_humidity) / 2 + (random() - 0.5) * humidityRange * 0.3;

      // A small number of bounded excursions make the sample series useful
      // for demonstrating quality changes while staying inside DB constraints.
      if (random() < 0.025) {
        const margin = Math.min(temperatureRange * (0.05 + random() * 0.3), Math.max(0, 100 - crop.max_temp));
        temperature = crop.max_temp + margin;
      } else if (random() < 0.025) {
        const margin = Math.min(humidityRange * (0.05 + random() * 0.3), Math.max(0, 100 - crop.max_humidity));
        humidity = crop.max_humidity + margin;
      }

      rows.push(`INSERT INTO readings(id,site,crop_id,temperature,humidity,data_source,recorded_at) VALUES(${id++},'demo-history',${crop.id},${temperature.toFixed(2)},${humidity.toFixed(2)},'synthetic-history',${quote(new Date(timestamp).toISOString())});`);
    }
  }

  sql(`BEGIN IMMEDIATE;\n${rows.join("\n")}\nINSERT INTO app_settings(key,value) VALUES('demo_history_seed_v1','1');\nCOMMIT;`);
}

function trendHistory(since) {
  return sql(`SELECT strftime('%Y-%m-%dT%H:00:00Z',r.recorded_at) AS recordedAt,c.name AS commodity,AVG(r.temperature) AS temperature,AVG(r.humidity) AS humidity,COUNT(*) AS count,SUM(CASE WHEN r.data_source='synthetic-history' THEN 1 ELSE 0 END) AS syntheticCount,SUM(CASE WHEN r.data_source='synthetic-history' THEN 0 ELSE 1 END) AS liveCount FROM readings r JOIN crops c ON c.id=r.crop_id WHERE r.recorded_at>=${quote(since)} GROUP BY recordedAt,c.name ORDER BY recordedAt,c.name;`, true);
}

module.exports = {
  seedDemoHistory,
  trendHistory,
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
  recentReadings: (limit = 200) => sql(`SELECT r.id,r.site,c.name AS commodity,r.temperature,r.humidity,r.data_source AS dataSource,r.recorded_at AS recordedAt FROM readings r JOIN crops c ON c.id=r.crop_id ORDER BY r.recorded_at DESC,r.id DESC LIMIT ${Math.max(1, Math.min(Number(limit) || 200, 2000))};`, true).reverse(),
};
