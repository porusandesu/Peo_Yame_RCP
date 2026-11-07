# Build Guide: Low-Cost IoT Storage Monitoring System (simulation-based)

> **Specification snapshot:** This file is an original build plan, not an
> up-to-date procedure for this checkout. Its proposed `better-sqlite3`,
> folder layout, schema, UI and test commands differ from the implemented
> Node/Express + SQLite CLI backend and Flutter app. Use [README.md](README.md),
> [backend/DEPLOYMENT.md](backend/DEPLOYMENT.md), and
> [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for current instructions and
> boundaries. Do not treat planned work below as implemented or verified.

Self-contained spec for building the whole project on one PC with Cursor's
free plan, with little back-and-forth. It can rebuild from zero. If working code
already exists (a `storage-demo` backend and a `storage_monitor_flutter` app),
use this file to check it against the spec instead.

Project: Group 3, Research Capstone C7-RCP-23. Supervisor: Lefentse Sorinyane.

---

## 0. How to work with Cursor's free plan

Free-plan request limits change over time, so check your plan page. Assume
requests are scarce and the context window is limited. Work like this:

1. **Put this file in the project root** and create `.cursor/rules/project.mdc`
   (or `.cursorrules`) containing the "Rules for the AI" from section 1.3, so
   every request already has the rules without pasting them.
2. **One small task per request.** Each prompt in section 12 is sized for one
   request. Do not combine tasks. Do not ask it to "build everything".
3. **Reference files, don't paste them.** Use `@BUILD_GUIDE_CURSOR.md` and
   name the section: "implement section 6".
4. **Verify after every task** with the check listed under the prompt. Fix by
   pasting the exact error text back, not by re-describing the project.
5. **Commit after every working step** (`git commit`) so a bad edit is
   one `git checkout .` away.
6. **Prefer writing code yourself from the spec when a step is trivial.**
   Save requests for the harder parts (simulator, Flutter UI).
7. If you run out of requests, the spec in this file is detailed enough to
   finish by hand or with any other assistant.

---

## 1. Project summary and rules

### 1.1 What it is
A low-cost system that monitors temperature and humidity in a produce storage
site and alerts a small agricultural aggregator (Botswana) before spoilage.
Parts: a sensor simulator, a backend API with SQLite, a web dashboard and
control panel, a trends page, an SMS alert service (logged, not sent), and a
Flutter phone app.

### 1.2 Honesty rules (marks depend on these)
- **Hardware could not be procured.** Readings come from a software
  simulator. Never call them real sensor data.
- **SMS is validated at dispatch-logic level**: an alert is created and a
  dispatch is logged with a timestamp. No real SMS is sent.
- Physical sensor calibration, real GSM testing and a field pilot are
  **future work**. Reports must say so.
- Everything marked done must have been run and seen working.
- Anyone submitting a file must be able to explain it. Say in the logbook that
  Cursor generated parts of the code.

### 1.3 Rules for the AI (paste into `.cursor/rules/project.mdc`)
```text
Project: IoT storage monitoring, simulation-based. See BUILD_GUIDE_CURSOR.md.
- Do one task per request. Show a short plan before editing files.
- Never change the response shapes of the four GET routes in section 5.
  Adding new routes is allowed.
- Keep it simple: Node.js + Express + SQLite (better-sqlite3), plain HTML/JS.
  No frameworks, no paid services, no cloud.
- Never describe simulated data as real. Never claim a real SMS was sent.
- Explain new files in two sentences at the end of your reply.
- After changes, tell me the exact commands to run and what I should see.
- Do not delete files or rewrite working code unless I ask.
```

---

## 2. Prerequisites

| Tool | Version | Used for |
|---|---|---|
| Node.js | 20 LTS or newer | backend |
| Git | any | version control |
| Cursor | free plan | AI assistant |
| Flutter SDK | stable | phone app (section 11) |
| JDK | **17** (not 25) | Android builds |
| Android SDK + platform tools | recent | APK |
| Android phone + USB cable | any | testing the app |

Check: `node -v`, `git --version`, `flutter doctor`, `java -version`.
The APK build is heavy and warms a laptop. Do it last and keep other apps closed.

---

## 3. Repository layout

```text
storage-monitor/
  BUILD_GUIDE_CURSOR.md
  .cursor/rules/project.mdc
  backend/
    package.json
    src/
      server.js            # Express app, routes, static files
      db.js                # SQLite setup, schema, seed, queries
      alerts.js            # threshold check, alert creation, cooldown
      sms_service.js       # SMS interface + console/log implementation
      simulator.js         # modelled sensor simulator (modes)
    public/
      index.html           # dashboard + control panel
      trends.html          # trends page
    test/
      api.test.js
      alerts.test.js
    scripts/
      benchmark_alerts.js
    data/                  # SQLite file lives here (git-ignored)
  mobile/                  # Flutter app (section 11)
  docs/
    walkthrough.md         # running log of what was built and verified
```

`.gitignore`: `node_modules/`, `backend/data/*.db`, `mobile/build/`,
`mobile/.dart_tool/`.

---

## 4. Data model (SQLite)

Use `better-sqlite3`. Create tables on startup if missing, then seed.

```sql
CREATE TABLE IF NOT EXISTS storage_site (
  site_id INTEGER PRIMARY KEY, name TEXT NOT NULL, location TEXT);

CREATE TABLE IF NOT EXISTS sensor (
  sensor_id INTEGER PRIMARY KEY, site_id INTEGER NOT NULL REFERENCES storage_site(site_id),
  sensor_type TEXT NOT NULL DEFAULT 'DHT22-simulated', status TEXT NOT NULL DEFAULT 'active');

CREATE TABLE IF NOT EXISTS commodity (
  commodity_id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);

CREATE TABLE IF NOT EXISTS threshold (
  threshold_id INTEGER PRIMARY KEY,
  commodity_id INTEGER NOT NULL REFERENCES commodity(commodity_id),
  min_temp REAL NOT NULL, max_temp REAL NOT NULL,
  min_humidity REAL NOT NULL, max_humidity REAL NOT NULL,
  active INTEGER NOT NULL DEFAULT 0);

CREATE TABLE IF NOT EXISTS reading (
  reading_id INTEGER PRIMARY KEY AUTOINCREMENT,
  sensor_id INTEGER NOT NULL REFERENCES sensor(sensor_id),
  temperature REAL NOT NULL, humidity REAL NOT NULL,
  recorded_at TEXT NOT NULL);            -- ISO 8601 UTC
CREATE INDEX IF NOT EXISTS idx_reading_time ON reading(recorded_at);

CREATE TABLE IF NOT EXISTS app_user (
  user_id INTEGER PRIMARY KEY, name TEXT NOT NULL,
  phone_number TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'manager');

CREATE TABLE IF NOT EXISTS alert (
  alert_id INTEGER PRIMARY KEY AUTOINCREMENT,
  reading_id INTEGER NOT NULL REFERENCES reading(reading_id),
  threshold_id INTEGER NOT NULL REFERENCES threshold(threshold_id),
  user_id INTEGER REFERENCES app_user(user_id),
  severity TEXT NOT NULL,                -- 'warning' | 'critical'
  message TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT 'sms-simulated',
  sent_at TEXT NOT NULL);

CREATE TABLE IF NOT EXISTS spoilage_incident (
  incident_id INTEGER PRIMARY KEY AUTOINCREMENT,
  site_id INTEGER NOT NULL REFERENCES storage_site(site_id),
  commodity_id INTEGER NOT NULL REFERENCES commodity(commodity_id),
  incident_date TEXT NOT NULL, cause TEXT, loss_estimate REAL);
```

**Seed data** (only if tables are empty):
- site: `Demo Storage Site`, `Gaborone (simulated)`
- sensor: one per site (`sensor_id` 1)
- commodities and thresholds (illustrative; cite storage literature in the report):

| commodity | min temp C | max temp C | min RH % | max RH % | active |
|---|---|---|---|---|---|
| Maize | 10 | 27 | 30 | 70 | 1 |
| Tomato | 10 | 20 | 85 | 95 | 0 |

- user: `Demo Manager`, phone `+26771234567`, role `manager`

---

## 5. API specification (the contract)

Base URL `http://<host>:3000`. JSON everywhere. Enable CORS. Listen on
`0.0.0.0` so phones can reach it.

### 5.1 Frozen GET routes (shapes must never change)

`GET /api/status`
```json
{
  "latest": { "id": 42, "temperature": 21.3, "humidity": 55.1, "recordedAt": "2026-10-10T14:29:16.539Z" },
  "threshold": { "commodity": "Maize", "minTemp": 10, "maxTemp": 27, "minHumidity": 30, "maxHumidity": 70 },
  "breached": false
}
```
`latest` is `null` if no readings exist yet.

`GET /api/readings/history?limit=50` -> oldest-first array of
`{ "id", "temperature", "humidity", "recordedAt" }`. Default limit 50, max 1000.

`GET /api/thresholds` -> the active threshold object (same shape as above).

`GET /api/alerts` -> newest-first array of
`{ "id", "readingId", "message", "sentAt" }`. Extra fields such as
`severity` are allowed, but the four above must stay.

### 5.2 Ingestion and control routes (new routes are allowed)

`POST /api/readings` body `{ "temperature": 31.5, "humidity": 78.2 }`
-> validates numbers (temp -20..80, humidity 0..100), stores a reading for
sensor 1 using the server clock, runs alert logic, returns
`{ "reading": {...}, "alert": {...} | null }` with status 201.
Bad input -> 400 `{ "error": "..." }`.

`GET /api/sim` -> `{ "running": true, "mode": "normal", "intervalMs": 5000 }`
`POST /api/sim` body `{ "running"?: bool, "mode"?: "normal"|"random"|"busy-day", "intervalMs"?: number }`
`POST /api/sim/breach` -> inject one out-of-range reading now (for demos/tests).

`GET /api/trends?window=60` -> `{ "points": [{ "t", "temperature", "humidity",
"tempAvg", "humAvg" }], "slope": { "temperature": 0.01, "humidity": -0.02 },
"note": "Indicative only" }` using a moving average (window in readings) and a
least-squares linear slope per hour. No ML.

`GET /api/sms-log` -> array of `{ "to", "body", "createdAt", "status": "logged" }`.

`GET /api/health` -> `{ "ok": true, "uptimeSec": 123, "readings": 456 }`.

---

## 6. Simulator specification (`simulator.js`)

Runs inside the server process, calling the same insert-and-check function as
`POST /api/readings`. Default: running, mode `normal`, every 5000 ms.

| Mode | Behaviour |
|---|---|
| `normal` | temp = 20 + 2*sin(2*pi*hourOfDay/24) + noise(sd 0.3); humidity = 55 + 5*sin(2*pi*(hourOfDay+6)/24) + noise(sd 1). Stays in range. |
| `random` | random walk (step sd 0.4 C, 1.0 %RH) around the normal curve with a 3% chance per tick of a spike that pushes it outside the threshold. |
| `busy-day` | normal curve plus **door events**: every 20-40 simulated minutes a worker event lifts temp by +3 to +6 C and humidity by +10 to +15 %RH for 2-5 minutes, then decays exponentially back (time constant ~3 minutes). Three or more events in an hour should produce a `warning`, a long one a `critical`. |

Rules:
- Clamp humidity to 0-100.
- Keep a `simulationClock` option: `speed` multiplier (default 1) so a 24 h
  curve can be demonstrated in minutes. Expose it as `speed` in `POST /api/sim`.
- Add a short comment block at the top of the file stating the model and that
  parameters are illustrative; the report should justify them from literature.

---

## 7. Alert logic and SMS service

### 7.1 Alert logic (`alerts.js`)
For each new reading, compare to the active threshold:
- inside range -> no alert
- outside range by up to 10% of the range width -> `warning`
- outside by more than 10% -> `critical`

Message example: `CRITICAL: temp 32.4C above 27C (Maize store). Check storage now.`

**Cooldown:** do not create another alert of the same severity for the same
metric within 10 minutes (configurable constant). A severity increase
(warning -> critical) always alerts. Store alerts in `alert`, with `sent_at` =
dispatch time, then call the SMS service.

### 7.2 SMS service (`sms_service.js`)
```js
// interface
class SmsService { async send(to, body) {} }
// implementation used now: logs + stores, never sends
class ConsoleSmsService extends SmsService { /* push to in-memory + table/log */ }
// future: GsmModuleService (SIM800/900) - not implemented, document only
```
- Format numbers to E.164 for Botswana: input `71234567`, `0 71234567` or
  `+26771234567` all become `+26771234567`. Reject numbers that are not 8 digits
  starting with 7 or 8 after the country code (return a clear error).
- Truncate message bodies to 160 characters.
- `GET /api/sms-log` reads what was "sent".
- **Measure latency:** record `breachAt` (reading time) and `dispatchAt`; the
  benchmark in section 10 reports the difference.

---

## 8. Dashboard and control panel (`public/index.html`)

Single HTML page with vanilla JS, polling `/api/status`, `/api/readings/history`
and `/api/alerts` every 5 s. No build step, no CDN dependencies if possible
(inline a tiny chart using `<canvas>`).

Must show:
- Status card: green "Conditions normal" / red "Threshold breached", latest
  temp and humidity, active commodity and range
- Line chart of the last 50 readings (temp and humidity)
- Alerts list with severity colour, message, time
- Control panel: mode selector (normal / random / busy-day), start/stop,
  speed, "Inject breach" button, active commodity selector
- A banner always visible: **"Simulated data. No physical sensors."**

Add `POST /api/commodity` body `{ "name": "Tomato" }` to switch the active
threshold.

---

## 9. Trends page (`public/trends.html`)

Read-only page for the manager. Uses `/api/trends`. Shows current status,
two charts with raw values and moving average, the slope as plain language
("Temperature rising about 0.6 C per hour"), and the note
"Indicative trend only, not a forecast." No machine learning.

---

## 10. Tests and benchmark

Use Node's built-in test runner (`node --test`). In `package.json`:
```json
"scripts": {
  "start": "node src/server.js",
  "demo": "node src/server.js",
  "test": "node --test test/",
  "benchmark": "node scripts/benchmark_alerts.js"
}
```
Tests must use a temporary database (set `DB_PATH` env var to a temp file).

`api.test.js`: contract shapes of the four GET routes; POST validation;
persistence (insert, reopen the DB, rows still there).
`alerts.test.js`: in range -> no alert; warning vs critical boundaries;
cooldown suppresses a repeat; severity increase bypasses cooldown;
phone number formatting cases.
`scripts/benchmark_alerts.js`: POST N=50 breaching readings and print
min / mean / max / p95 of breach-to-dispatch latency in ms, plus alert count
and SMS-log count. Also write the numbers to `docs/benchmark_results.txt`.

---

## 11. Flutter phone app (`mobile/`)

Purpose: show the same status and alerts on a phone.

- Packages: `http`, `shared_preferences`.
- Files: `lib/config.dart` (default address, overridable with
  `--dart-define=API_BASE_URL=...`), `lib/settings.dart` (load/save/normalise
  the address), `lib/models.dart` (Reading, Threshold, StatusResponse, Alert
  matching section 5.1), `lib/api_service.dart`, `lib/dashboard_controller.dart`
  (ChangeNotifier, polls every 5 s, error message naming the address),
  `lib/main.dart` (Material 3 dashboard).
- UI: status card (green/red), latest temperature and humidity, safe range,
  recent alerts list, pull-to-refresh, and a **gear icon** opening a dialog to
  type the server address (for example `192.168.1.42:3000`), saved on the phone.
  Add `http://` if missing and strip trailing slashes.
- Default address `http://10.0.2.2:3000` is for the emulator only. A real
  phone needs the laptop's LAN IP.
- `AndroidManifest.xml` must contain
  `<uses-permission android:name="android.permission.INTERNET"/>` and
  `android:usesCleartextTraffic="true"` on `<application>` (plain HTTP).

Build (use JDK 17):
```bash
cd mobile
flutter clean && flutter pub get
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```
If Gradle errors mention Java 25, set `JAVA_HOME` to JDK 17 and run
`cd android && ./gradlew --stop`, then rebuild.

Test on a phone: same Wi-Fi as the laptop; open `http://<laptop-ip>:3000` in the
phone browser first; if that fails, allow port 3000 in the firewall or use the
laptop's hotspot. Then install the APK and set the address with the gear icon.

---

## 12. Build order with Cursor prompts

Run them in order. Each is one request. Commit after each check passes.

**Step 1: scaffold the backend**
```text
Read @BUILD_GUIDE_CURSOR.md sections 3, 4 and 5.1. Create backend/ with
package.json (express, cors, better-sqlite3), src/db.js (schema + seed from
section 4, DB_PATH env var), and src/server.js implementing the four frozen GET
routes and GET /api/health on 0.0.0.0:3000. No simulator yet. Show a plan first.
```
Check: `npm install && npm start`, then `curl localhost:3000/api/status` returns
`latest: null`.

**Step 2: ingestion and alerts**
```text
Implement section 5.2 POST /api/readings and section 7 (alerts.js and
sms_service.js with ConsoleSmsService, E.164 formatting for Botswana, 160-char
limit, cooldown) wired into the POST route. Add GET /api/sms-log.
```
Check: `curl -X POST localhost:3000/api/readings -H "Content-Type: application/json"
-d '{"temperature":32.4,"humidity":55}'` returns an alert; `/api/alerts` lists it;
`/api/status` shows `breached: true`.

**Step 3: simulator**
```text
Implement section 6 in src/simulator.js and the GET/POST /api/sim and
POST /api/sim/breach routes. It must call the same insert-and-check function as
POST /api/readings. Add the model comment block at the top.
```
Check: readings arrive every 5 s; switching to `busy-day` produces spikes.

**Step 4: tests and benchmark**
```text
Implement section 10: test/api.test.js, test/alerts.test.js using node:test and a
temporary DB, plus scripts/benchmark_alerts.js writing docs/benchmark_results.txt.
```
Check: `npm test` passes; `npm run benchmark` prints latency numbers. Save the output.

**Step 5: dashboard and control panel**
```text
Implement section 8 as backend/public/index.html served statically by the
server, plus POST /api/commodity. Vanilla JS and canvas only.
```
Check: open `http://localhost:3000`, change mode, inject a breach, see red status.

**Step 6: trends**
```text
Implement GET /api/trends (section 5.2) and backend/public/trends.html
(section 9). Moving average and least-squares slope only.
```
Check: the page shows charts and a plain-language slope sentence.

**Step 7: Flutter app**
```text
Create the Flutter app in mobile/ following section 11. Use the frozen API
shapes from section 5.1. Do not build the APK; just make it analyse cleanly
(flutter analyze).
```
Check: `flutter analyze` has no errors. Then build the APK yourself (section 11).

**Step 8: write `docs/walkthrough.md`**
```text
Create docs/walkthrough.md summarising what exists, how to run it, test
results, and known limitations (simulation only, SMS logged not sent).
Only include commands that exist in package.json.
```

---

## 13. Verification checklist (do before calling it done)

- [ ] `npm test` passes
- [ ] `npm run benchmark` output saved (`docs/benchmark_results.txt`)
- [ ] Restart the server: earlier readings and alerts are still there
- [ ] Four frozen GET routes return the section 5.1 shapes
- [ ] Inject a breach: status red, alert listed, SMS log entry with timestamps
- [ ] `busy-day` mode produces door-event spikes and alerts
- [ ] Dashboard banner says data is simulated
- [ ] Phone browser reaches `http://<laptop-ip>:3000`
- [ ] APK installs; gear icon address works; status matches the dashboard
- [ ] 24-48 h run: log uptime, crashes, and reading count (use `/api/health`)

### Evidence to save for the reports
Breach test screenshot (red status + alert with timestamps), restart test,
benchmark file, phone screenshots (green then red), uptime log, commit history.

---

## 14. Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Phone app says "can't reach" | Wrong address. Use laptop LAN IP + `:3000`, same Wi-Fi, check browser first |
| Works in browser, not in app | Missing INTERNET permission or cleartext flag in the manifest |
| `better-sqlite3` install fails | Use Node 20 LTS; reinstall; on Windows install build tools |
| Gradle error mentioning Java 25 | Use JDK 17, `./gradlew --stop`, rebuild |
| Port 3000 busy | Stop the other process or set `PORT` env var |
| Cursor changed a response shape | `git checkout .`, then re-prompt with "do not change section 5.1 shapes" |
| Laptop overheating | Close other apps; build the APK on another machine |

---

## 15. Definition of done

The system runs from one `npm run demo`, readings persist, alerts and logged
SMS dispatches appear with timestamps, three simulation modes work, a trends
page and dashboard exist, the Flutter app runs on a phone against the same API,
tests and benchmark have saved output, and the docs state plainly that data is
simulated and SMS is logged, not sent.

## 16. Future work (state in the report; do not build now)
Real ESP32 + DHT22 firmware and calibration against a reference sensor, real
GSM transmission (SIM800/900) and delivery-rate testing, a pilot at a real
aggregator site, multi-site support, and authenticated staff accounts.
