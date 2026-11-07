const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { dataDirectory } = require("./runtime_paths");

// Uses SQLite's native CLI so the backend has no downloaded native npm addon.
// User supplied strings are always SQL string literals (single quotes doubled).
let sqliteCommand = process.env.SQLITE3_PATH || "sqlite3";
if (process.pkg && process.platform === "win32") {
  sqliteCommand = path.join(os.tmpdir(), "peo-yame-sqlite3.exe");
  if (!fs.existsSync(sqliteCommand)) {
    fs.writeFileSync(sqliteCommand, fs.readFileSync(path.join(__dirname, "vendor", "sqlite3.exe")));
  }
}

const file = process.env.DATABASE_PATH || path.join(dataDirectory, "storage-monitor.sqlite");
fs.mkdirSync(path.dirname(file), { recursive: true });
function quote(value) { return `'${String(value).replaceAll("'", "''")}'`; }
function sql(statement, asJson = false) {
  const args = asJson ? ["-json", file] : [file];
  // Set the CLI timeout with its dot command. `PRAGMA busy_timeout` returns a
  // result row, which would otherwise be concatenated with SELECT results in
  // `-json` mode and make the combined output invalid JSON.
  const output = execFileSync(sqliteCommand, args, { input: `.timeout 5000\nPRAGMA foreign_keys=ON;\n${statement}\n`, encoding: "utf8", maxBuffer: 32 * 1024 * 1024 });
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
CREATE TABLE IF NOT EXISTS farmer_accounts (
  id INTEGER PRIMARY KEY,
  phone TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  email TEXT UNIQUE COLLATE NOCASE,
  password_salt TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  authenticator_secret TEXT,
  pending_authenticator_secret TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE TABLE IF NOT EXISTS farmer_sessions (
  token_hash TEXT PRIMARY KEY,
  farmer_id INTEGER NOT NULL REFERENCES farmer_accounts(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS farmer_sessions_expiry_idx ON farmer_sessions(expires_at);
CREATE TABLE IF NOT EXISTS auth_challenges (
  challenge_hash TEXT PRIMARY KEY,
  purpose TEXT NOT NULL CHECK(purpose IN ('web_login','mobile_login')),
  farmer_id INTEGER REFERENCES farmer_accounts(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  used_at TEXT,
  approved_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE TABLE IF NOT EXISTS storage_sites (
  id INTEGER PRIMARY KEY,
  farmer_id INTEGER NOT NULL REFERENCES farmer_accounts(id) ON DELETE CASCADE,
  crop_id INTEGER NOT NULL REFERENCES crops(id),
  label TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(farmer_id,label)
);
CREATE TABLE IF NOT EXISTS farmer_sensors (
  sensor_id TEXT PRIMARY KEY,
  farmer_id INTEGER NOT NULL REFERENCES farmer_accounts(id) ON DELETE CASCADE,
  site_id INTEGER REFERENCES storage_sites(id) ON DELETE SET NULL,
  linked_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE TABLE IF NOT EXISTS readings (
  id INTEGER PRIMARY KEY, site TEXT NOT NULL, crop_id INTEGER NOT NULL REFERENCES crops(id),
  sensor_id TEXT,
  temperature REAL NOT NULL, humidity REAL NOT NULL CHECK(humidity BETWEEN 0 AND 100),
  data_source TEXT NOT NULL, recorded_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS readings_recorded_at_idx ON readings(recorded_at);`);

const readingColumns = new Set(sql("PRAGMA table_info(readings);", true).map((column) => column.name));
if (!readingColumns.has("sensor_id")) sql("ALTER TABLE readings ADD COLUMN sensor_id TEXT;");

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

function farmerSiteRows(farmerId, siteId = null) {
  const siteFilter = siteId == null ? "" : ` AND s.id=${Number(siteId)}`;
  return sql(`SELECT s.id,s.label,s.crop_id AS cropId,c.name AS commodity,c.crop_group AS cropGroup,c.min_temp AS minTemp,c.max_temp AS maxTemp,c.min_humidity AS minHumidity,c.max_humidity AS maxHumidity,c.safe_moisture_pct AS safeMoisturePct,c.storage_note AS storageNote,COALESCE(GROUP_CONCAT(fs.sensor_id,'|'),'') AS sensorIds FROM storage_sites s JOIN crops c ON c.id=s.crop_id LEFT JOIN farmer_sensors fs ON fs.site_id=s.id WHERE s.farmer_id=${Number(farmerId)}${siteFilter} GROUP BY s.id ORDER BY s.id;`, true).map((site) => ({
    ...site,
    sensors: site.sensorIds ? site.sensorIds.split("|") : [],
  }));
}

module.exports = {
  seedDemoHistory,
  trendHistory,
  listCrops: () => sql("SELECT * FROM crops ORDER BY name COLLATE NOCASE;", true).map(toCrop),
  createFarmer: ({ phone, name, email, passwordSalt, passwordHash }) => {
    sql(`INSERT INTO farmer_accounts(phone,name,email,password_salt,password_hash) VALUES(${quote(phone)},${quote(name)},${email ? quote(email) : "NULL"},${quote(passwordSalt)},${quote(passwordHash)});`);
    return sql(`SELECT id,phone,name,email,created_at AS createdAt FROM farmer_accounts WHERE phone=${quote(phone)};`, true)[0];
  },
  farmerByPhone: (phone) => sql(`SELECT * FROM farmer_accounts WHERE phone=${quote(phone)} LIMIT 1;`, true)[0] || null,
  farmerByEmail: (email) => sql(`SELECT * FROM farmer_accounts WHERE email=${quote(email)} COLLATE NOCASE LIMIT 1;`, true)[0] || null,
  farmerById: (id) => sql(`SELECT id,phone,name,email,created_at AS createdAt FROM farmer_accounts WHERE id=${Number(id)} LIMIT 1;`, true)[0] || null,
  updateFarmer: (id, { name, email }) => {
    sql(`UPDATE farmer_accounts SET name=${quote(name)},email=${email ? quote(email) : "NULL"} WHERE id=${Number(id)};`);
    return sql(`SELECT id,phone,name,email,created_at AS createdAt FROM farmer_accounts WHERE id=${Number(id)} LIMIT 1;`, true)[0] || null;
  },
  setAuthenticatorSecret: (id, secret) => sql(`UPDATE farmer_accounts SET pending_authenticator_secret=${secret ? quote(secret) : "NULL"} WHERE id=${Number(id)};`),
  enableAuthenticator: (id) => sql(`UPDATE farmer_accounts SET authenticator_secret=pending_authenticator_secret,pending_authenticator_secret=NULL WHERE id=${Number(id)} AND pending_authenticator_secret IS NOT NULL;`),
  disableAuthenticator: (id) => sql(`UPDATE farmer_accounts SET authenticator_secret=NULL,pending_authenticator_secret=NULL WHERE id=${Number(id)};`),
  authenticatorForFarmer: (id, pending = false) => {
    const column = pending ? "pending_authenticator_secret" : "authenticator_secret";
    return sql(`SELECT ${column} AS secret FROM farmer_accounts WHERE id=${Number(id)};`, true)[0]?.secret || null;
  },
  createSession: (tokenHash, farmerId, expiresAt) => sql(`INSERT INTO farmer_sessions(token_hash,farmer_id,expires_at) VALUES(${quote(tokenHash)},${Number(farmerId)},${quote(expiresAt)});`),
  farmerForSession: (tokenHash) => sql(`SELECT f.id,f.phone,f.name,f.email,f.created_at AS createdAt,s.expires_at AS expiresAt FROM farmer_sessions s JOIN farmer_accounts f ON f.id=s.farmer_id WHERE s.token_hash=${quote(tokenHash)} AND s.expires_at>strftime('%Y-%m-%dT%H:%M:%fZ','now') LIMIT 1;`, true)[0] || null,
  deleteSession: (tokenHash) => sql(`DELETE FROM farmer_sessions WHERE token_hash=${quote(tokenHash)};`),
  cleanupExpiredSessions: () => sql("DELETE FROM farmer_sessions WHERE expires_at<=strftime('%Y-%m-%dT%H:%M:%fZ','now');"),
  createAuthChallenge: (challengeHash, purpose, farmerId, expiresAt) => sql(`INSERT INTO auth_challenges(challenge_hash,purpose,farmer_id,expires_at) VALUES(${quote(challengeHash)},${quote(purpose)},${farmerId == null ? "NULL" : Number(farmerId)},${quote(expiresAt)});`),
  approveAuthChallenge: (challengeHash, farmerId) => sql(`UPDATE auth_challenges SET farmer_id=${Number(farmerId)},approved_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE challenge_hash=${quote(challengeHash)} AND purpose='web_login' AND approved_at IS NULL AND used_at IS NULL AND expires_at>strftime('%Y-%m-%dT%H:%M:%fZ','now');`),
  authChallenge: (challengeHash) => sql(`SELECT purpose,farmer_id AS farmerId,expires_at AS expiresAt,used_at AS usedAt,approved_at AS approvedAt FROM auth_challenges WHERE challenge_hash=${quote(challengeHash)} LIMIT 1;`, true)[0] || null,
  consumeAuthChallenge: (challengeHash, purpose) => sql(`UPDATE auth_challenges SET used_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE challenge_hash=${quote(challengeHash)} AND purpose=${quote(purpose)} AND used_at IS NULL AND expires_at>strftime('%Y-%m-%dT%H:%M:%fZ','now')${purpose === "web_login" ? " AND approved_at IS NOT NULL" : " AND farmer_id IS NOT NULL"}; SELECT changes() AS changed;`, true).at(-1)?.changed === 1,
  cleanupAuthChallenges: () => sql("DELETE FROM auth_challenges WHERE expires_at<=strftime('%Y-%m-%dT%H:%M:%fZ','now') OR (used_at IS NOT NULL AND used_at<strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 day'));") ,
  addFarmerSite: (farmerId, commodity, label) => {
    const crop = findCrop(commodity);
    if (!crop) return null;
    sql(`INSERT INTO storage_sites(farmer_id,crop_id,label) VALUES(${Number(farmerId)},${crop.id},${quote(label)});`);
    return farmerSiteRows(farmerId).at(-1) || null;
  },
  farmerSites: (farmerId) => farmerSiteRows(farmerId),
  deleteFarmerSite: (farmerId, siteId) => sql(`DELETE FROM storage_sites WHERE farmer_id=${Number(farmerId)} AND id=${Number(siteId)}; SELECT changes() AS changed;`, true).at(-1)?.changed === 1,
  observedSensorIds: () => sql("SELECT DISTINCT sensor_id AS sensorId FROM readings WHERE data_source='sensor' AND sensor_id IS NOT NULL ORDER BY sensor_id;", true).map((item) => item.sensorId),
  availableFarmerSensors: (farmerId) => sql(`SELECT DISTINCT r.sensor_id AS sensorId,MAX(r.recorded_at) AS lastSeen FROM readings r LEFT JOIN farmer_sensors fs ON fs.sensor_id=r.sensor_id WHERE r.data_source='sensor' AND r.sensor_id IS NOT NULL AND fs.sensor_id IS NULL GROUP BY r.sensor_id ORDER BY lastSeen DESC;`, true),
  farmerSensors: (farmerId) => sql(`SELECT fs.sensor_id AS sensorId,fs.site_id AS siteId,s.label AS siteLabel,fs.linked_at AS linkedAt,MAX(r.recorded_at) AS lastSeen FROM farmer_sensors fs LEFT JOIN storage_sites s ON s.id=fs.site_id LEFT JOIN readings r ON r.sensor_id=fs.sensor_id WHERE fs.farmer_id=${Number(farmerId)} GROUP BY fs.sensor_id ORDER BY fs.sensor_id;`, true),
  linkFarmerSensor: (farmerId, sensorId, siteId) => {
    if (!sql(`SELECT 1 AS ok FROM readings WHERE data_source='sensor' AND sensor_id=${quote(sensorId)} LIMIT 1;`, true).length) return false;
    if (siteId != null && !sql(`SELECT 1 AS ok FROM storage_sites WHERE id=${Number(siteId)} AND farmer_id=${Number(farmerId)} LIMIT 1;`, true).length) return null;
    sql(`INSERT INTO farmer_sensors(sensor_id,farmer_id,site_id) VALUES(${quote(sensorId)},${Number(farmerId)},${siteId == null ? "NULL" : Number(siteId)});`);
    return true;
  },
  unlinkFarmerSensor: (farmerId, sensorId) => sql(`DELETE FROM farmer_sensors WHERE farmer_id=${Number(farmerId)} AND sensor_id=${quote(sensorId)}; SELECT changes() AS changed;`, true).at(-1)?.changed === 1,
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
    const sensorId = reading.sensorId || (reading.dataSource === "sensor" ? reading.site : null);
    sql(`INSERT INTO readings(id,site,sensor_id,crop_id,temperature,humidity,data_source,recorded_at) VALUES(${reading.id},${quote(reading.site)},${sensorId ? quote(sensorId) : "NULL"},${crop.id},${reading.temperature},${reading.humidity},${quote(reading.dataSource)},${quote(reading.recordedAt)});`);
  },
  recentReadings: (limit = 200) => sql(`SELECT r.id,r.site,c.name AS commodity,r.temperature,r.humidity,r.data_source AS dataSource,r.recorded_at AS recordedAt FROM readings r JOIN crops c ON c.id=r.crop_id ORDER BY r.recorded_at DESC,r.id DESC LIMIT ${Math.max(1, Math.min(Number(limit) || 200, 2000))};`, true).reverse(),
};
