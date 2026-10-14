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

For a build-time address override, use
`flutter run --dart-define=API_BASE_URL=http://192.168.1.42:3000`.

## Project context

- [Build guide](BUILD_GUIDE_FOR_CURSOR_AI.md)
- [Phone app demo guide](PHONE_APP_DEMO_VSCODE.md)

Use the project only as a controlled local-network demonstration. The backend
uses plain HTTP and has no authentication or persistent storage.
