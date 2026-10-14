# Peo Yame presentation walkthrough

Peo Yame is a local-network prototype for simulated produce-storage monitoring.
The web dashboard and Flutter app use the included Node.js API. The app's visual
style follows the dashboard, with summary cards and compact trend views inspired
by health dashboards.

## Start the system

Start the backend on the PC:

```bash
cd backend
npm install
npm run demo
```

Open `http://localhost:3000` on the PC to see the web dashboard. For a phone,
connect both devices to the same Wi-Fi, open the app's settings, and enter the
PC's LAN address, for example `192.168.1.42:3000`. Android emulators use the
default `http://10.0.2.2:3000` address.

The app refreshes status, alerts, readings, and trend data every five seconds.
Pull down to refresh manually, or tap the warning icon to inject a sample breach.
The trend selector shows 24 hours, one month, or three months. At startup, the
backend generates a stable, explicitly synthetic 24-hour baseline so the chart
is populated immediately. Live simulated readings are added after startup;
older month history is collected only while the backend is running. Restarting
the backend clears the in-memory trend history.

## Presentation flow

1. Show the desktop dashboard and the phone app together.
2. Point out the safe or breached status, the temperature and humidity risk
   gauges, and the selected trend range.
3. Trigger a sample breach and show the alert appearing in both interfaces.
4. Explain the system limitations: readings are simulated, no physical sensor
   is connected, SMS alerts are logged but not sent, and the storage-time
   estimate is illustrative rather than a validated spoilage model.

## Key files

- `backend/server.js` — demo API, reading simulator, and trend summaries.
- `backend/public/index.html` — responsive Peo Yame web dashboard.
- `lib/main.dart` — Flutter dashboard and mobile visualizations.
- `lib/dashboard_controller.dart` — polling and screen state.
- `lib/api_service.dart` — backend HTTP requests.
- `lib/models.dart` — API response models.
- `lib/config.dart` — emulator default and saved-address normalization.

The backend uses plain HTTP, in-memory storage, and no authentication. Keep the
system on a controlled local network during demonstrations.
