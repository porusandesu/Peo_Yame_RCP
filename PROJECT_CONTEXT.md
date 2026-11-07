# Project Context: Low-Cost IoT-Based Post-Harvest Storage Monitoring System

> **Current implementation (7 Nov 2026):** This is a Flutter + Node/Express
> local-network demonstration. SQLite stores crop/settings/reading data and
> farmer accounts, email/password hashes, hashed sessions, crop locations and
> sensor assignments. Alerts, simulated SMS entries, incidents, and short-lived
> sign-in challenges are in memory; action history is JSONL. Farmer account
> routes are authenticated, but global monitoring and sensor-ingestion APIs
> remain unscoped. Mobile sign-in uses a one-use QR issued after web sign-in;
> demo web verification can be skipped and does not disclose a PIN. Readings
> are simulated; no physical sensor or SMS service is connected. See
> [README.md](README.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md),
> [docs/HANDOFF.md](docs/HANDOFF.md), and [docs/TEST_REPORT.md](docs/TEST_REPORT.md)
> for current behavior and verification. The proposal sections below describe
> research intent, not implemented capabilities.

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

## Current status (7 Nov 2026)

- [x] Responsive HTML/JavaScript dashboard and Flutter mobile client use the demo API.
- [x] Web farmer accounts use phone verification in the demo, optional email/password credentials, and optional Google Authenticator. Demo PINs are not returned; a demo-only skip is available.
- [x] Mobile sign-in uses one-use QR pairing created by an already signed-in web account. Farmer accounts and crop assignments share data through the same backend.
- [x] SQLite persists crop profiles, app settings, readings, farmer accounts, password hashes, bearer-session hashes, farmer crop locations and sensor assignments; action history is JSONL.
- [x] Simulated readings, threshold alerts, trend views, exports, and demo breach controls are available.
- [x] Mobile navigation has five tabs, with My Crops centered; backend polling runs every 20 seconds and tolerates two missed refreshes before reporting offline.
- [ ] ESP32/DHT22 sensor ingestion and GSM/SMS delivery are not connected.
- [ ] Global readings, status, alert, and sensor-ingestion APIs are not account-scoped; assigned sensor IDs are not authenticated device identities.
- [ ] Thresholds and sample sensor readings are illustrative; no calibration, field pilot, or validated spoilage model is established.

**If you are an agent reading this:** do not assume hardware integration is
done. Check `backend/server.js` to distinguish generated readings from sensor
POSTs; an accepted sensor-style payload does not authenticate a physical device.

## Research target architecture (not the current runtime)

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

- **Current backend**: Node.js + Express; SQLite for crops, settings, and readings; in-memory alert/SMS/incident collections; JSONL action history.
- **Current clients**: responsive plain HTML/CSS/JavaScript web dashboard and Flutter mobile app.
- **Current data**: simulated readings plus seeded synthetic trend history; no physical device or SMS provider.
- **Research target**: ESP32/DHT22/GSM integration and authenticated account/device data. These remain future scope, not current capabilities.
- **Dashboard guidance**: extend the existing UI and preserve clear simulation labels; do not rewrite it from scratch.

## Current demo API compatibility

The web and Flutter clients use the current route shapes in `backend/server.js`.
Before changing a route, inspect its handlers and both clients, then update the
API, web dashboard, Flutter models/services, and
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) together. The Kotlin/Retrofit
contract described in older proposal material is not the current client.

## Proposed research-target database schema (not the current SQLite schema)

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

## Research non-functional requirements (confirm before changing scope)

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

## Implementation backlog (confirm scope and access before scheduling)

1. Agree the approved interim-report scope and list unimplemented items accurately.
2. Decide whether authentication and account-owned multi-sensor data are in scope.
3. Confirm access, budget, ethics, and safety before adding hardware or SMS integration.
4. If devices become available, document calibration, uptime, alert timing, and data provenance.
5. Capture dated screenshots, logs, and evaluation evidence for report claims.

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
