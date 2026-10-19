# Project Context: Low-Cost IoT-Based Post-Harvest Storage Monitoring System

> **Baseline status (15 Oct 2026):** The architecture and status below describe
> the intended research system and include historical notes; they do not all
> describe the current top-level implementation. For the inspected code, test
> evidence, objective traceability, risks, and current limitations, see
> [docs/BASELINE_AUDIT.md](docs/BASELINE_AUDIT.md),
> [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and
> [docs/TEST_REPORT.md](docs/TEST_REPORT.md). In particular, the current
> runtime is a Flutter + Node/Express simulation with in-memory domain data,
> two illustrative crop settings, and no physical sensor, SQLite database, or
> real SMS dispatch.

> Import this file into Antigravity (drop it in your project root, or `@`
> reference it in your first prompt) so the agent has full context without
> you re-explaining the project every session.

## What this project is

A low-cost IoT system that monitors temperature/humidity in a produce
storage site and alerts an agricultural aggregator (small business) before
spoilage occurs. Built for a university Research Capstone Project
(C7-RCP-23). Target users are small agricultural aggregators in Botswana
with unreliable internet connectivity — this is why GSM/SMS alerting is a
first-class requirement, not an optional extra.

## Current status (update this section as work progresses)

- [x] Database schema designed (see ER diagram below)
- [x] HTML dashboard built (currently showing MOCK/SIMULATED data, not live sensor data)
- [x] Demo backend (Node.js/Express) built with a mock data generator standing in for real sensors
- [x] Demo Android app (Kotlin + Jetpack Compose) built, polling the demo backend
- [ ] ESP32 + DHT22 + GSM/SMS hardware NOT yet wired to the backend — **this is the current #1 blocker**
- [ ] Real database (not in-memory mock) not yet connected
- [ ] SMS alert dispatch not yet tested with real hardware
- [ ] End-to-end testing not yet started

**If you are an agent reading this: do not assume the hardware integration
is done. Always check `backend/server.js` for whether `generateReading()`
is still a mock function before assuming live data is flowing.**

## Architecture

```
ESP32 + DHT22 sensor + GSM/SMS module
        |
        v
Backend API (Node.js/Express) — ingestion, threshold logic, alert dispatch
        |
        v
Database (readings, thresholds, alerts, spoilage incidents)
        |
        v
   ___________________
   |                 |
HTML Dashboard   Android App (Kotlin + Compose + Retrofit)
```

## Tech stack

- **Firmware**: ESP32, DHT22 sensor, GSM/SMS module (e.g. SIM800/900 class)
- **Backend**: Node.js + Express, currently in-memory mock data — needs
  migrating to a real database (SQLite is the lowest-friction choice for a
  single-site pilot; don't over-engineer into Postgres/MySQL unless asked)
- **Database schema**: see ER diagram below — readings, thresholds,
  alerts, storage sites, sensors, commodities, spoilage incidents, users
- **Android app**: Kotlin, Jetpack Compose, Retrofit, polling-based (not
  push notifications) — keep it this way unless explicitly asked to add
  push, polling is sufficient for this use case
- **Dashboard**: plain HTML/JS, already built by a teammate — do not
  rewrite it from scratch; extend it to point at the real API instead

## API contract (DO NOT change these routes/shapes without updating both the dashboard AND the Android app)

- `GET /api/status` → `{ latest, threshold, breached }`
- `GET /api/readings/history?limit=50` → array of readings
- `GET /api/thresholds` → current threshold config
- `GET /api/alerts` → array of alerts

The Android app and dashboard are both built against these exact shapes.
If you need to change a response shape, update all three (backend route,
dashboard JS, Android `Models.kt` + `ApiService.kt`) in the same task —
don't let them drift out of sync.

## Database schema (ER diagram, Mermaid)

```mermaid
erDiagram
  STORAGE_SITE ||--o{ SENSOR : hosts
  STORAGE_SITE ||--o{ SPOILAGE_INCIDENT : records
  SENSOR ||--o{ READING : produces
  COMMODITY ||--o{ THRESHOLD : defines
  COMMODITY ||--o{ SPOILAGE_INCIDENT : involves
  THRESHOLD ||--o{ ALERT : triggers
  READING ||--o{ ALERT : triggers
  USER ||--o{ ALERT : receives

  STORAGE_SITE { int site_id PK, string name, string location }
  SENSOR { int sensor_id PK, int site_id FK, string sensor_type, string status }
  READING { int reading_id PK, int sensor_id FK, float temperature, float humidity, datetime recorded_at }
  COMMODITY { int commodity_id PK, string name }
  THRESHOLD { int threshold_id PK, int commodity_id FK, float min_temp, float max_temp, float min_humidity, float max_humidity }
  ALERT { int alert_id PK, int reading_id FK, int threshold_id FK, int user_id FK, string channel, datetime sent_at }
  SPOILAGE_INCIDENT { int incident_id PK, int site_id FK, int commodity_id FK, date incident_date, string cause, float loss_estimate }
  USER { int user_id PK, string name, string phone_number, string role }
```

Note: this schema is a draft inferred from the project proposal — if the
team's actual built database differs, treat the real schema as the source
of truth and update this file to match it.

## Non-functional requirements (don't silently drop these for convenience)

- **Low cost**: don't suggest paid cloud services, premium APIs, or
  managed hosting unless explicitly asked — this project is cost-sensitive
  by design
- **Connectivity tolerance**: alerting MUST work over SMS/GSM, not just
  WiFi — don't "simplify" by making WiFi push notifications the only
  alert channel
- **Usability**: dashboard and app should stay simple enough for
  non-technical aggregator staff — avoid adding complexity/jargon to the UI
- **Data integrity**: readings/alerts/incidents must persist across
  restarts (this is exactly why the mock in-memory backend needs
  replacing with a real database)

## Immediate priority order (as of Interim Report 3, testing phase)

1. Confirm/complete real sensor → backend integration (replace mock
   `generateReading()` in `backend/server.js`)
2. Migrate from in-memory arrays to a real database (SQLite)
3. Test SMS alert dispatch with real hardware
4. Run 24-48 hours of continuous accuracy/uptime logging
5. Manually trigger and time several alerts for response-time data
6. Document results (screenshots, logs) for the report — don't just fix
   things silently, capture evidence as you go

## Working conventions for the agent

- One task per conversation — don't try to do integration + database
  migration + testing in a single prompt
- Always check whether a "fix" changes the API contract above before
  applying it
- Prefer the simplest solution that meets the non-functional requirements
  — this is a student capstone project on a tight timeline, not a
  production system that needs to scale past one pilot site
- Generate a `walkthrough.md` summary after each completed task — these
  get used as evidence in the project's contribution logbook
