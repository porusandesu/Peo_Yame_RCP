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
  // Set the CLI timeout with its dot command. `PRAGMA busy_timeout` returns a
  // result row, which would otherwise be concatenated with SELECT results in
  // `-json` mode and make the combined output invalid JSON.
  const output = execFileSync("sqlite3", args, { input: `.timeout 5000\nPRAGMA foreign_keys=ON;\n${statement}\n`, encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
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
  crop_group TEXT NOT NULL DEFAULT 'Other',
  safe_moisture_pct REAL CHECK(safe_moisture_pct BETWEEN 0 AND 100),
  storage_note TEXT NOT NULL DEFAULT '',
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

const cropColumns = new Set(sql('PRAGMA table_info(crops);', true).map((column) => column.name));
if (!cropColumns.has('crop_group')) sql("ALTER TABLE crops ADD COLUMN crop_group TEXT NOT NULL DEFAULT 'Other';");
if (!cropColumns.has('safe_moisture_pct')) sql('ALTER TABLE crops ADD COLUMN safe_moisture_pct REAL CHECK(safe_moisture_pct BETWEEN 0 AND 100);');
if (!cropColumns.has('storage_note')) sql("ALTER TABLE crops ADD COLUMN storage_note TEXT NOT NULL DEFAULT '';");

function toCrop(row) {
  return row && {
    id: row.id,
    commodity: row.name,
    cropGroup: row.crop_group || 'Other',
    minTemp: row.min_temp,
    maxTemp: row.max_temp,
    minHumidity: row.min_humidity,
    maxHumidity: row.max_humidity,
    safeMoisturePct: row.safe_moisture_pct ?? null,
    storageNote: row.storage_note || '',
  };
}
function findCrop(name) {
  return sql(`SELECT * FROM crops WHERE name=${quote(name)} COLLATE NOCASE LIMIT 1;`, true)[0];
}

const grainNote = 'Indicative room-monitoring limits only. Grain moisture is a separate measurement: measure it with a grain moisture meter. Dry fully, protect from pests, and inspect stores regularly.';
const freshNote = 'Indicative cold-store target for intact produce. Variety, maturity, curing, airflow, and intended use change the suitable setting. Avoid condensation and separate produce with incompatible temperature or ripening needs.';
for (const crop of [
  { commodity: 'Maize', group: 'Grain', minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, moisture: 13.5, note: grainNote },
  { commodity: 'Sorghum', group: 'Grain', minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, moisture: 13.5, note: grainNote },
  { commodity: 'Pearl millet', group: 'Grain', minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, moisture: 16, note: grainNote },
  { commodity: 'Cowpea', group: 'Pulse', minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, moisture: 14, note: grainNote },
  { commodity: 'Common beans', group: 'Pulse', minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, moisture: 15, note: grainNote },
  { commodity: 'Pigeon pea', group: 'Pulse', minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, moisture: 14, note: grainNote },
  { commodity: 'Groundnuts (shelled)', group: 'Oilseed', minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, moisture: 7, note: grainNote },
  { commodity: 'Sunflower seed', group: 'Oilseed', minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, moisture: 9, note: grainNote },
  { commodity: 'Tomato', group: 'Vegetable', minTemp: 10, maxTemp: 12, minHumidity: 85, maxHumidity: 95, note: `${freshNote} Ripe and green tomatoes need different handling; avoid chilling green fruit.` },
  { commodity: 'Potato', group: 'Vegetable', minTemp: 7, maxTemp: 10, minHumidity: 90, maxHumidity: 95, note: `${freshNote} Keep dark and ventilated. Processing potatoes may need warmer storage.` },
  { commodity: 'Cabbage', group: 'Vegetable', minTemp: 0, maxTemp: 2, minHumidity: 95, maxHumidity: 100, note: freshNote },
  { commodity: 'Dry onion', group: 'Vegetable', minTemp: 0, maxTemp: 2, minHumidity: 65, maxHumidity: 70, note: `${freshNote} Cure and dry outer skins; use good ventilation.` },
  { commodity: 'Carrot', group: 'Vegetable', minTemp: 0, maxTemp: 2, minHumidity: 95, maxHumidity: 100, note: freshNote },
  { commodity: 'Leafy greens', group: 'Vegetable', minTemp: 0, maxTemp: 2, minHumidity: 95, maxHumidity: 100, note: `${freshNote} Cool promptly and avoid wilting.` },
  { commodity: 'Green pepper', group: 'Vegetable', minTemp: 7, maxTemp: 10, minHumidity: 90, maxHumidity: 95, note: `${freshNote} Chilling sensitivity depends on variety and storage duration.` },
  { commodity: 'Sweet potato', group: 'Vegetable', minTemp: 13, maxTemp: 15, minHumidity: 85, maxHumidity: 90, note: `${freshNote} Cure harvested roots before longer storage; avoid chilling.` },
  { commodity: 'Orange', group: 'Fruit', minTemp: 4, maxTemp: 8, minHumidity: 90, maxHumidity: 95, note: freshNote },
  { commodity: 'Lemon', group: 'Fruit', minTemp: 10, maxTemp: 13, minHumidity: 85, maxHumidity: 90, note: freshNote },
  { commodity: 'Mango', group: 'Fruit', minTemp: 10, maxTemp: 13, minHumidity: 85, maxHumidity: 90, note: `${freshNote} Ripeness and variety affect chilling sensitivity.` },
  { commodity: 'Avocado', group: 'Fruit', minTemp: 10, maxTemp: 13, minHumidity: 90, maxHumidity: 95, note: `${freshNote} Target varies with cultivar and maturity.` },
  { commodity: 'Green banana', group: 'Fruit', minTemp: 13, maxTemp: 15, minHumidity: 85, maxHumidity: 90, note: `${freshNote} For green fruit; ripe fruit needs different conditions.` },
  { commodity: 'Watermelon', group: 'Fruit', minTemp: 10, maxTemp: 15, minHumidity: 85, maxHumidity: 90, note: `${freshNote} Avoid colder settings that may cause chilling injury.` },
  { commodity: 'Mandarin', group: 'Fruit', minTemp: 4, maxTemp: 8, minHumidity: 90, maxHumidity: 95, note: freshNote },
  { commodity: 'Grapefruit', group: 'Fruit', minTemp: 10, maxTemp: 15, minHumidity: 85, maxHumidity: 90, note: freshNote },
]) {
  const safeMoisture = crop.moisture == null ? 'NULL' : crop.moisture;
  sql(`INSERT INTO crops(name,min_temp,max_temp,min_humidity,max_humidity,crop_group,safe_moisture_pct,storage_note) VALUES(${quote(crop.commodity)},${crop.minTemp},${crop.maxTemp},${crop.minHumidity},${crop.maxHumidity},${quote(crop.group)},${safeMoisture},${quote(crop.note)}) ON CONFLICT(name) DO UPDATE SET min_temp=excluded.min_temp,max_temp=excluded.max_temp,min_humidity=excluded.min_humidity,max_humidity=excluded.max_humidity,crop_group=excluded.crop_group,safe_moisture_pct=excluded.safe_moisture_pct,storage_note=excluded.storage_note;`);
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
    sql(`INSERT INTO crops(name,min_temp,max_temp,min_humidity,max_humidity,crop_group) VALUES(${quote(crop.commodity)},${crop.minTemp},${crop.maxTemp},${crop.minHumidity},${crop.maxHumidity},'Other');`);
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
