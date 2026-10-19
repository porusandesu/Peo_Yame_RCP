# Peo Yame

Peo Yame is a presentation prototype for monitoring produce-storage conditions.
The responsive web dashboard and Flutter app read simulated temperature,
humidity, status, and alerts from the included Node.js backend. No physical
sensor is connected and no SMS is sent; alert dispatches appear in the
backend's in-memory SMS log. The chart starts with a clearly labeled, stable
simulated 24-hour baseline, then adds live simulated readings. Trend history is
cleared when the backend restarts.

## Start the backend on the PC

```bash
cd backend
npm install
npm run demo
```

Open `http://localhost:3000` to view the web dashboard, or
`http://localhost:3000/api/status` to inspect the API. The server listens on
`0.0.0.0:3000` for a phone on the same Wi-Fi network. Find the PC's
Wi-Fi IP with `hostname -I` on Linux, `ipconfig` on Windows, or
`ipconfig getifaddr en0` on macOS. If the phone cannot reach the PC, check the
firewall and that both devices are on the same network.

## Connect the Android phone

Run the Flutter app on the phone. Tap the settings gear and enter the PC address,
for example `192.168.1.42:3000`. The app adds `http://` when needed and saves
the address on the phone. The default `10.0.2.2` address is for an Android
emulator only.

Use the warning icon to trigger a deterministic out-of-range reading held for
15 seconds. The status card turns red and the alert appears in the app. The web
dashboard also shows recent readings, alerts, and the simulated SMS log. Open
`http://<PC-IP>:3000` on another device on the same Wi-Fi network. The backend
keeps readings and logs in memory, so restarting it clears them.

Use the **Harvest** selector to switch between Maize and Tomato. Each selection
loads that crop's illustrative temperature and humidity limits and immediately
adds an in-range simulated reading for the selected crop.

The backend also exposes `/api/health` and sensor-gateway endpoints. To run an
optional simulated sensor that follows the selected harvest, start the backend
first, then run `cd backend && npm run simulate:sensor` in a second terminal.
Sensor readings can be submitted with `POST /api/readings`; recent readings are
available from `GET /api/readings?limit=60`. Alerts can be acknowledged through
`POST /api/alerts/:id/acknowledge`, and incident records use `GET` and `POST`
`/api/incidents`.

## Activity log export

The backend records dashboard and app actions, including harvest changes,
manual refreshes, trend-range changes, alert actions, incident records, sensor
submissions, and demo breaches. The web dashboard's download icon saves a
Markdown file; the Flutter app's export icon opens the device share sheet with
the same file. The API is also available at `GET /api/actions/export.md`.
Entries persist in `backend/data/actions.jsonl` (ignored by Git) and are capped
at the most recent 2,500 actions. Backend startup and export events are logged
too.

## Excel data export

Use the spreadsheet icon in the web dashboard to download `peo-yame-readings.csv`.
The Flutter app offers the same file through the device share sheet. Excel opens
the CSV directly. It includes the latest retained readings, UTC timestamps,
harvest, data source, temperature and humidity, crop limits, and a breach flag.
Reading history is held in memory and capped at 200 records, so export it before
restarting the backend if you need to keep the current dataset. The synthetic
24-hour chart baseline is labeled separately in the chart and is not included
as sensor readings in this file.

For a build-time address override, use
`flutter run --dart-define=API_BASE_URL=http://192.168.1.42:3000`.

## Project context

- [Build guide](BUILD_GUIDE_FOR_CURSOR_AI.md)
- [Phone app demo guide](PHONE_APP_DEMO_VSCODE.md)
- [Baseline audit, traceability, and research-claim status](docs/BASELINE_AUDIT.md)
- [Implemented architecture](docs/ARCHITECTURE.md)
- [Prioritised risk register](docs/RISK_REGISTER.md)
- [Verification record](docs/TEST_REPORT.md)

The audit documents the implementation present in this branch, including
known gaps between the presentation prototype and the research proposal. Crop
limits in the demo are illustrative software settings; they are not validated
spoilage thresholds. The UI's storage-time estimate is a heuristic and must
not be presented as a validated prediction.

Use the project only as a controlled local-network demonstration. The backend
uses plain HTTP and has no authentication or persistent storage.
