# Peo Yame — Storage Monitor

Peo Yame is a Flutter and responsive web prototype for monitoring produce
storage conditions. Both clients display simulated temperature/humidity data,
configured-limit status, trends, and alerts through a Node.js backend. SQLite
persists crop settings and readings; no physical sensor or SMS provider is
connected. Demo mode opens directly as Mr Lesego Lefoko
(`LLefoko@email.co.bw`). It does not request phone verification or create an
authenticated account.

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

## Build the Android app with GitHub Actions

The **Android build** workflow runs when code is pushed and can also be started
from the repository's **Actions** tab with **Run workflow**. When it finishes,
open the run and download the `storage-monitor-android-debug` artifact. Extract
it and install `app-debug.apk` on an Android device. This is a debug build for
testing, not a Play Store release.

On either app, tap **Demo mode** to open the home page immediately. The shared
profile is Mr Lesego Lefoko (`LLefoko@email.co.bw`). The dashboard and its
breach control are demonstrations; they do not authenticate a user, connect a
physical sensor, or send SMS. Open `http://<PC-IP>:3000` on another device on
the same Wi-Fi network to use the web demo.

In the web app, use the header account menu or the Accounts/My Crops shortcuts.
In the mobile app, open **Accounts & crops** from the Overview user menu. The
crop groups, sensor IDs, readings and online/offline states on these screens are
fixed demo fixtures. Search and filters work locally; sensor linking, account
editing and live sensor status are not connected to backend records or physical
devices.

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
The export includes the latest 200 readings. Longer chart history remains in
SQLite and is shown as simulated history, separate from live readings.

For a build-time address override, use
`flutter run --dart-define=API_BASE_URL=http://192.168.1.42:3000`.

## Project context

- [Interim report specification pack](docs/interim-report-specs/README.md)
- [Build guide](BUILD_GUIDE_FOR_CURSOR_AI.md)
- [Phone app demo guide](PHONE_APP_DEMO_VSCODE.md)
- [Baseline audit, traceability, and research-claim status](docs/BASELINE_AUDIT.md)
- [Implemented architecture](docs/ARCHITECTURE.md)
- [Botswana starter crop package and sources](docs/BOTSWANA_CROP_STORAGE_PACKAGE.md)
- [Current handoff and next build steps](docs/HANDOFF.md)
- [Prioritised risk register](docs/RISK_REGISTER.md)
- [Verification record](docs/TEST_REPORT.md)

The audit documents the implementation present in this branch, including
known gaps between the presentation prototype and the research proposal. Crop
limits in the demo are indicative software settings; they are not validated
spoilage thresholds. The dashboard reports whether readings are within the
configured target band. It does not estimate crop quality or remaining storage
time.

Use the project only as a controlled local-network demonstration. The backend
uses plain HTTP and demo mode has no authentication. Do not expose it to the
public internet.
