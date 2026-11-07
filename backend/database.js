const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { dataDirectory } = require("./runtime_paths");

// Packaged Windows builds embed sqlite3.exe and extract it to the OS temp
// directory on first use. Source runs continue to use sqlite3 from PATH.
let sqliteCommand = process.env.SQLITE3_PATH || "sqlite3";
if (process.pkg) {
  sqliteCommand = path.join(os.tmpdir(), "peo-yame-sqlite3.exe");
  if (!fs.existsSync(sqliteCommand)) {
    fs.writeFileSync(sqliteCommand, fs.readFileSync(path.join(__dirname, "vendor", "sqlite3.exe")));
  }
}

// Windows packages store user data under Local AppData so the EXE can also be
// launched from read-only folders. DATABASE_PATH can override this location.
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
  safe_moisture_pct REAL CHECK(safe_moisture_pct BETWEEN 0 AND 100),
  storage_note TEXT NOT NULL DEFAULT '',
  crop_group TEXT NOT NULL DEFAULT 'Other',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK(min_temp < max_temp), CHECK(min_humidity < max_humidity)
);
CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS readings (
  id INTEGER PRIMARY KEY, site TEXT NOT NULL, crop_id INTEGER NOT NULL REFERENCES crops(id),
  temperature REAL NOT NULL, humidity REAL NOT NULL CHECK(humidity BETWEEN 0 AND 100),
  data_source TEXT NOT NULL, recorded_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS farmer_accounts (
  id INTEGER PRIMARY KEY, phone TEXT NOT NULL UNIQUE COLLATE NOCASE,
  name TEXT NOT NULL, email TEXT NOT NULL DEFAULT '', password_salt TEXT, password_hash TEXT,
  totp_secret TEXT, pending_totp_secret TEXT,
  demo_security_skipped INTEGER NOT NULL DEFAULT 0 CHECK(demo_security_skipped IN (0,1)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE TABLE IF NOT EXISTS farmer_sessions (
  token_hash TEXT PRIMARY KEY,
  account_id INTEGER NOT NULL REFERENCES farmer_accounts(id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS farmer_crops (
  id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES farmer_accounts(id) ON DELETE CASCADE,
  crop_id INTEGER NOT NULL REFERENCES crops(id), label TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(account_id,crop_id,label)
);
CREATE TABLE IF NOT EXISTS farmer_sensors (
  id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES farmer_accounts(id) ON DELETE CASCADE,
  farmer_crop_id INTEGER NOT NULL REFERENCES farmer_crops(id) ON DELETE CASCADE,
  sensor_code TEXT NOT NULL, label TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(account_id,sensor_code)
);
CREATE INDEX IF NOT EXISTS readings_recorded_at_idx ON readings(recorded_at);`);

const farmerColumns = new Set(sql("PRAGMA table_info(farmer_accounts);", true).map((column) => column.name));
if (!farmerColumns.has("email")) sql("ALTER TABLE farmer_accounts ADD COLUMN email TEXT NOT NULL DEFAULT '';");
if (!farmerColumns.has("password_salt")) sql("ALTER TABLE farmer_accounts ADD COLUMN password_salt TEXT;");
if (!farmerColumns.has("password_hash")) sql("ALTER TABLE farmer_accounts ADD COLUMN password_hash TEXT;");
if (!farmerColumns.has("totp_secret")) sql("ALTER TABLE farmer_accounts ADD COLUMN totp_secret TEXT;");
if (!farmerColumns.has("pending_totp_secret")) sql("ALTER TABLE farmer_accounts ADD COLUMN pending_totp_secret TEXT;");
if (!farmerColumns.has("demo_security_skipped")) sql("ALTER TABLE farmer_accounts ADD COLUMN demo_security_skipped INTEGER NOT NULL DEFAULT 0 CHECK(demo_security_skipped IN (0,1));");
const cropColumns = new Set(sql("PRAGMA table_info(crops);", true).map((column) => column.name));
if (!cropColumns.has("safe_moisture_pct")) sql("ALTER TABLE crops ADD COLUMN safe_moisture_pct REAL CHECK(safe_moisture_pct BETWEEN 0 AND 100);");
if (!cropColumns.has("storage_note")) sql("ALTER TABLE crops ADD COLUMN storage_note TEXT NOT NULL DEFAULT '';");
if (!cropColumns.has("crop_group")) sql("ALTER TABLE crops ADD COLUMN crop_group TEXT NOT NULL DEFAULT 'Other';");

function toCrop(row) {
  return row && { id: row.id, commodity: row.name, cropGroup: row.crop_group || 'Other', minTemp: row.min_temp, maxTemp: row.max_temp, minHumidity: row.min_humidity, maxHumidity: row.max_humidity, safeMoisturePct: row.safe_moisture_pct ?? null, storageNote: row.storage_note || '' };
}
function findCrop(name) {
  return sql(`SELECT * FROM crops WHERE name=${quote(name)} COLLATE NOCASE LIMIT 1;`, true)[0];
}

function availableBackendSensors() {
  return sql(`SELECT UPPER(TRIM(r.site)) AS sensorCode,MAX(r.recorded_at) AS lastSeen FROM readings r WHERE r.data_source='sensor' AND NOT EXISTS (SELECT 1 FROM farmer_sensors fs WHERE UPPER(fs.sensor_code)=UPPER(TRIM(r.site))) GROUP BY UPPER(TRIM(r.site)) ORDER BY sensorCode LIMIT 200;`, true)
    .filter((sensor) => /^[A-Z0-9][A-Z0-9_-]{2,39}$/.test(sensor.sensorCode));
}

const SENSOR_ONLINE_WINDOW_MS = 5 * 60 * 1000;

const grainNote = "Indicative room-monitoring alerts only. Safe moisture is a grain target, not room humidity; measure it with a grain moisture meter. Drying, aeration, cleanliness, pest control, packaging, and storage duration also affect quality.";
const freshNote = "Cold-store starter target for intact produce. Cultivar, maturity/ripeness, curing, intended use, packaging, airflow, and storage duration affect the suitable setting; avoid condensation and separate incompatible produce.";
for (const crop of [
  { commodity: "Maize", group: "Grain", minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, safeMoisturePct: 13, note: grainNote },
  { commodity: "Sorghum", group: "Grain", minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, safeMoisturePct: 13, note: grainNote },
  { commodity: "Millet", group: "Grain", minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, safeMoisturePct: 13, note: grainNote },
  { commodity: "Cowpea", group: "Pulse", minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, safeMoisturePct: 14, note: grainNote },
  { commodity: "Common beans", group: "Pulse", minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, safeMoisturePct: 14, note: grainNote },
  { commodity: "Pigeon pea", group: "Pulse", minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, safeMoisturePct: 14, note: grainNote },
  { commodity: "Groundnuts (shelled)", group: "Oilseed", minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, safeMoisturePct: 7, note: grainNote },
  { commodity: "Sunflower seed", group: "Oilseed", minTemp: 10, maxTemp: 27, minHumidity: 30, maxHumidity: 65, safeMoisturePct: 8, note: grainNote },
  { commodity: "Tomato", group: "Vegetable", minTemp: 10, maxTemp: 12, minHumidity: 85, maxHumidity: 90, safeMoisturePct: null, note: `${freshNote} Use for mature tomatoes; avoid chilling green or ripening fruit.` },
  { commodity: "Potato", group: "Vegetable", minTemp: 7, maxTemp: 10, minHumidity: 90, maxHumidity: 95, safeMoisturePct: null, note: `${freshNote} Keep in darkness. Processing potatoes may need a warmer setting to reduce cold-induced sweetening.` },
  { commodity: "Cabbage", group: "Vegetable", minTemp: 0, maxTemp: 1, minHumidity: 95, maxHumidity: 100, safeMoisturePct: null, note: freshNote },
  { commodity: "Onion (dry bulb)", group: "Vegetable", minTemp: 0, maxTemp: 2, minHumidity: 70, maxHumidity: 75, safeMoisturePct: null, note: `${freshNote} Cure and dry outer skins before storage; keep airflow high and avoid damp conditions.` },
  { commodity: "Carrot", group: "Vegetable", minTemp: 0, maxTemp: 1, minHumidity: 90, maxHumidity: 95, safeMoisturePct: null, note: freshNote },
  { commodity: "Spinach and leafy greens", group: "Vegetable", minTemp: 0, maxTemp: 2, minHumidity: 95, maxHumidity: 100, safeMoisturePct: null, note: `${freshNote} Highly perishable; cool promptly and keep leaves from wilting.` },
  { commodity: "Green pepper", group: "Vegetable", minTemp: 8, maxTemp: 12, minHumidity: 90, maxHumidity: 95, safeMoisturePct: null, note: freshNote },
  { commodity: "Sweet potato", group: "Vegetable", minTemp: 13, maxTemp: 15, minHumidity: 85, maxHumidity: 90, safeMoisturePct: null, note: `${freshNote} Cure harvested roots before longer storage; tropical roots can be injured by chilling.` },
  { commodity: "Orange", group: "Fruit", minTemp: 6, maxTemp: 8, minHumidity: 90, maxHumidity: 95, safeMoisturePct: null, note: freshNote },
  { commodity: "Lemon", group: "Fruit", minTemp: 10, maxTemp: 13, minHumidity: 85, maxHumidity: 90, safeMoisturePct: null, note: freshNote },
  { commodity: "Mango", group: "Fruit", minTemp: 10, maxTemp: 13, minHumidity: 85, maxHumidity: 90, safeMoisturePct: null, note: `${freshNote} Avoid colder settings that can cause chilling injury.` },
  { commodity: "Avocado", group: "Fruit", minTemp: 12, maxTemp: 16, minHumidity: 90, maxHumidity: 95, safeMoisturePct: null, note: `${freshNote} Target varies with cultivar and maturity; avoid chilling sensitive fruit.` },
  { commodity: "Banana (green)", group: "Fruit", minTemp: 13, maxTemp: 14, minHumidity: 85, maxHumidity: 90, safeMoisturePct: null, note: `${freshNote} For green fruit; ripening and ripe-fruit settings differ.` },
  { commodity: "Watermelon", group: "Fruit", minTemp: 10, maxTemp: 15, minHumidity: 85, maxHumidity: 90, safeMoisturePct: null, note: `${freshNote} Avoid very cold storage because chilling injury is possible.` },
  { commodity: "Mandarin (naartjie)", group: "Fruit", minTemp: 4, maxTemp: 8, minHumidity: 90, maxHumidity: 95, safeMoisturePct: null, note: freshNote },
  { commodity: "Grapefruit", group: "Fruit", minTemp: 14, maxTemp: 15, minHumidity: 85, maxHumidity: 90, safeMoisturePct: null, note: `${freshNote} This target follows guidance for fruit from dry regions; harvest and cultivar still matter.` },
]) {
  const moisture = crop.safeMoisturePct === null ? "NULL" : crop.safeMoisturePct;
  sql(`INSERT INTO crops(name,min_temp,max_temp,min_humidity,max_humidity,safe_moisture_pct,storage_note,crop_group) VALUES(${quote(crop.commodity)},${crop.minTemp},${crop.maxTemp},${crop.minHumidity},${crop.maxHumidity},${moisture},${quote(crop.note)},${quote(crop.group)}) ON CONFLICT(name) DO UPDATE SET min_temp=excluded.min_temp,max_temp=excluded.max_temp,min_humidity=excluded.min_humidity,max_humidity=excluded.max_humidity,safe_moisture_pct=excluded.safe_moisture_pct,storage_note=excluded.storage_note,crop_group=excluded.crop_group;`);
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
  findFarmer: (phone) => sql(`SELECT id,name,phone,email,(password_hash IS NOT NULL) AS passwordEnabled,demo_security_skipped AS demoSecuritySkipped,totp_secret IS NOT NULL AS authenticatorEnabled FROM farmer_accounts WHERE phone=${quote(phone)} COLLATE NOCASE;`, true)[0] || null,
  getOrCreateDemoFarmer: () => {
    sql(`INSERT INTO farmer_accounts(phone,name,email) VALUES('DEMO','Mr Lesego Lefoko','LLefoko@email.co.bw') ON CONFLICT(phone) DO UPDATE SET name=excluded.name,email=excluded.email;`);
    return sql(`SELECT id,name,phone,email,(password_hash IS NOT NULL) AS passwordEnabled,demo_security_skipped AS demoSecuritySkipped,totp_secret IS NOT NULL AS authenticatorEnabled FROM farmer_accounts WHERE phone='DEMO';`, true)[0] || null;
  },
  findFarmerById: (id) => sql(`SELECT id,name,phone,email,(password_hash IS NOT NULL) AS passwordEnabled,demo_security_skipped AS demoSecuritySkipped FROM farmer_accounts WHERE id=${Number(id)};`, true)[0] || null,
  findFarmerByEmail: (email) => sql(`SELECT id,name,phone,email,(password_hash IS NOT NULL) AS passwordEnabled,password_salt AS passwordSalt,password_hash AS passwordHash FROM farmer_accounts WHERE email=${quote(email)} COLLATE NOCASE AND password_hash IS NOT NULL;`, true)[0] || null,
  findFarmerByEmailAddress: (email) => sql(`SELECT id FROM farmer_accounts WHERE email=${quote(email)} COLLATE NOCASE LIMIT 1;`, true)[0] || null,
  createFarmer: (phone, name, email = "") => {
    sql(`INSERT INTO farmer_accounts(phone,name,email) VALUES(${quote(phone)},${quote(name)},${quote(email)});`);
    return sql(`SELECT id,name,phone,email FROM farmer_accounts WHERE phone=${quote(phone)} COLLATE NOCASE;`, true)[0];
  },
  updateFarmerAccount: (id, name, phone, email = "") => {
    sql(`UPDATE farmer_accounts SET name=${quote(name)},phone=${quote(phone)},email=${quote(email)} WHERE id=${Number(id)};`);
    return sql(`SELECT id,name,phone,email FROM farmer_accounts WHERE id=${Number(id)};`, true)[0] || null;
  },
  updateFarmerCredentials: (id, email, salt, hash) => {
    sql(`UPDATE farmer_accounts SET email=${quote(email)},password_salt=${quote(salt)},password_hash=${quote(hash)} WHERE id=${Number(id)};`);
    return sql(`SELECT id,name,phone,email,(password_hash IS NOT NULL) AS passwordEnabled FROM farmer_accounts WHERE id=${Number(id)};`, true)[0] || null;
  },
  markFarmerDemoSecuritySkipped: (id) => {
    sql(`UPDATE farmer_accounts SET demo_security_skipped=1 WHERE id=${Number(id)};`);
    return sql(`SELECT id,name,phone,email,(password_hash IS NOT NULL) AS passwordEnabled,demo_security_skipped AS demoSecuritySkipped FROM farmer_accounts WHERE id=${Number(id)};`, true)[0] || null;
  },
  farmerAuthenticator: (accountId) => sql(`SELECT totp_secret AS secret,pending_totp_secret AS pendingSecret FROM farmer_accounts WHERE id=${Number(accountId)};`, true)[0] || null,
  setPendingAuthenticator: (accountId, secret) => sql(`UPDATE farmer_accounts SET pending_totp_secret=${quote(secret)} WHERE id=${Number(accountId)} AND totp_secret IS NULL;`),
  enableAuthenticator: (accountId) => sql(`UPDATE farmer_accounts SET totp_secret=pending_totp_secret,pending_totp_secret=NULL WHERE id=${Number(accountId)} AND pending_totp_secret IS NOT NULL;`),
  disableAuthenticator: (accountId) => sql(`UPDATE farmer_accounts SET totp_secret=NULL,pending_totp_secret=NULL WHERE id=${Number(accountId)};`),
  createFarmerSession: (tokenHash, accountId, expiresAt) => {
    sql(`DELETE FROM farmer_sessions WHERE expires_at<=${Number(Date.now())}; INSERT INTO farmer_sessions(token_hash,account_id,expires_at) VALUES(${quote(tokenHash)},${Number(accountId)},${Number(expiresAt)});`);
  },
  findFarmerBySession: (tokenHash, now = Date.now()) => sql(`SELECT a.id,a.name,a.phone,a.email,(a.password_hash IS NOT NULL) AS passwordEnabled,a.demo_security_skipped AS demoSecuritySkipped FROM farmer_sessions s JOIN farmer_accounts a ON a.id=s.account_id WHERE s.token_hash=${quote(tokenHash)} AND s.expires_at>${Number(now)};`, true)[0] || null,
  removeFarmerSession: (tokenHash) => sql(`DELETE FROM farmer_sessions WHERE token_hash=${quote(tokenHash)};`),
  farmerCrops: (accountId) => sql(`SELECT fc.id,fc.label,c.name AS commodity,c.min_temp AS minTemp,c.max_temp AS maxTemp,c.min_humidity AS minHumidity,c.max_humidity AS maxHumidity,(SELECT COUNT(*) FROM farmer_sensors fs WHERE fs.farmer_crop_id=fc.id) AS sensorCount FROM farmer_crops fc JOIN crops c ON c.id=fc.crop_id WHERE fc.account_id=${Number(accountId)} ORDER BY fc.id;`, true),
  addFarmerCrop: (accountId, commodity, label) => {
    const crop = findCrop(commodity);
    if (!crop) return null;
    sql(`INSERT INTO farmer_crops(account_id,crop_id,label) VALUES(${Number(accountId)},${crop.id},${quote(label)});`);
    return sql(`SELECT id,label FROM farmer_crops WHERE account_id=${Number(accountId)} AND crop_id=${crop.id} AND label=${quote(label)};`, true)[0];
  },
  availableFarmerSensors: availableBackendSensors,
  addFarmerCropWithSensors: (accountId, commodity, label, sensorCodes) => {
    const crop = findCrop(commodity);
    if (!crop) return null;
    const selected = [...new Set(sensorCodes.map((code) => String(code).trim().toUpperCase()))];
    if (!selected.length || selected.length > 20) throw new Error("Select between one and 20 backend sensors.");
    if (selected.some((code) => !/^[A-Z0-9][A-Z0-9_-]{2,39}$/.test(code))) throw new Error("A selected sensor ID is invalid.");
    const available = new Set(availableBackendSensors()
      .filter((sensor) => Date.now() - Date.parse(sensor.lastSeen) <= SENSOR_ONLINE_WINDOW_MS)
      .map((sensor) => sensor.sensorCode));
    const unavailable = selected.filter((code) => !available.has(code));
    if (unavailable.length) throw new Error(`These sensors are no longer available: ${unavailable.join(", ")}. Refresh the list.`);
    const statements = [
      "BEGIN IMMEDIATE;",
      `INSERT INTO farmer_crops(account_id,crop_id,label) VALUES(${Number(accountId)},${crop.id},${quote(label)});`,
      ...selected.map((code) => `INSERT INTO farmer_sensors(account_id,farmer_crop_id,sensor_code,label) SELECT ${Number(accountId)},fc.id,${quote(code)},${quote(code)} FROM farmer_crops fc WHERE fc.account_id=${Number(accountId)} AND fc.crop_id=${crop.id} AND fc.label=${quote(label)};`),
      "COMMIT;",
      `SELECT id,label,${crop.id} AS cropId FROM farmer_crops WHERE account_id=${Number(accountId)} AND crop_id=${crop.id} AND label=${quote(label)};`,
    ];
    return sql(statements.join("\n"), true)[0] || null;
  },
  removeFarmerCrop: (accountId, cropId) => sql(`DELETE FROM farmer_crops WHERE account_id=${Number(accountId)} AND id=${Number(cropId)}; SELECT changes() AS removed;`, true)[0]?.removed > 0,
  farmerSensors: (accountId) => sql(`SELECT fs.id,fs.sensor_code AS sensorCode,fs.label,fc.id AS farmerCropId,fc.label AS cropLabel,c.name AS commodity,fs.created_at AS createdAt FROM farmer_sensors fs JOIN farmer_crops fc ON fc.id=fs.farmer_crop_id JOIN crops c ON c.id=fc.crop_id WHERE fs.account_id=${Number(accountId)} ORDER BY fs.id;`, true),
  addFarmerSensor: (accountId, cropId, sensorCode, label) => {
    const crop = sql(`SELECT id FROM farmer_crops WHERE id=${Number(cropId)} AND account_id=${Number(accountId)};`, true)[0];
    if (!crop) return null;
    sql(`INSERT INTO farmer_sensors(account_id,farmer_crop_id,sensor_code,label) VALUES(${Number(accountId)},${Number(cropId)},${quote(sensorCode)},${quote(label)});`);
    return sql(`SELECT id,sensor_code AS sensorCode,label,farmer_crop_id AS farmerCropId FROM farmer_sensors WHERE account_id=${Number(accountId)} AND sensor_code=${quote(sensorCode)};`, true)[0];
  },
  removeFarmerSensor: (accountId, sensorId) => sql(`DELETE FROM farmer_sensors WHERE account_id=${Number(accountId)} AND id=${Number(sensorId)}; SELECT changes() AS removed;`, true)[0]?.removed > 0,
};
