# Storage Monitor Backend

Ingests sensor readings, applies per-commodity spoilage-risk thresholds,
raises alerts on breach, and serves everything to the staff dashboard.
This is the "back-end service" and "database" pieces described in section
1.8 of the project proposal.

No physical hardware is connected yet, so `simulate-sensor.js` stands in
for the Arduino + DHT22 + GSM module, posting fake-but-realistic readings
the same way the real device eventually will.

## Setup

```bash
npm install
npm start          # starts the API on http://localhost:3000
```

In a second terminal, to generate test data without hardware:

```bash
npm run simulate                       # simulates a "tomato" sensor
COMMODITY=maize npm run simulate       # or simulate a different commodity
```

The database is a single SQLite file, `storage_monitor.db`, created
automatically on first run — nothing to install or configure. Three
commodities (tomato, leafy greens, maize) are seeded with default
thresholds on first startup.

## API reference

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/health` | Basic liveness check |
| POST | `/api/readings` | Ingest one sensor reading: `{ site?, commodity, temperature, humidity }`. Checks thresholds and creates an alert if breached. |
| GET | `/api/readings?commodity=&limit=` | Recent readings, oldest first (for charting) |
| GET | `/api/readings/latest?commodity=` | Most recent reading + its threshold |
| GET | `/api/thresholds` | All configured commodity thresholds |
| POST | `/api/thresholds` | Create/update a threshold: `{ commodity, temp_max, hum_max }` |
| GET | `/api/alerts?limit=&unacknowledged=true` | Recent alerts |
| POST | `/api/alerts/:id/acknowledge` | Mark an alert as handled |
| GET | `/api/incidents` | Spoilage/loss incident log |
| POST | `/api/incidents` | Log an incident: `{ incident_date, commodity, breach_description, duration?, outcome }` (`outcome` is `"loss"` or `"noloss"`) |

## Connecting the dashboard

In `storage_dashboard.html`, replace the random-walk logic inside `tick()`
with calls to this API, e.g.:

```js
async function tick() {
  const res = await fetch('http://localhost:3000/api/readings/latest?commodity=tomato');
  const { reading, threshold } = await res.json();
  // update current.temp / current.hum from `reading`,
  // update `thresholds` from `threshold`, then call render() as before
}
```

The alert list and incident table can similarly be populated from
`GET /api/alerts` and `GET /api/incidents` instead of the in-memory arrays.

## Moving off SQLite later

The proposal mentions MySQL/PostgreSQL or a lightweight time-series store
as options. Because all database access goes through `db.js`, switching
engines later mainly means replacing that one file with a client for the
new database and updating the SQL in `routes/*.js` to match its dialect —
the rest of the app is unaffected.

## When real hardware arrives

Replace `simulate-sensor.js` with the actual firmware/gateway code that
reads the DHT22 and posts over the GSM/SMS or WiFi link. As long as it
sends the same JSON shape to `POST /api/readings`, nothing else in the
backend or dashboard needs to change.
