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

The web and mobile clients receive live updates from the backend and reconnect
if the event stream drops; a slower periodic refresh is also available. Pull
down to refresh manually. Enable Demo mode in Settings (mobile) or the account
menu (web) to show the breach control. Repeated triggers cycle through four
quality impact levels. The trend selector shows 24 hours, one month, or three
months. Demo startup seeds a deterministic 90-day hourly history in SQLite;
new simulated readings are then stored alongside it.

## Presentation flow

1. Show the desktop dashboard and the phone app together.
2. Point out the safe or breached status, the temperature and humidity risk
   gauges, and the selected trend range.
3. Change Harvest between Maize and Tomato and show the matching limits and
   simulated reading update.
4. Enable Demo mode, trigger a sample breach, and show the alert and quality
   estimate updating in both interfaces.
5. Explain the system limitations: readings are simulated, no physical sensor
   is connected, SMS alerts are logged but not sent, and the storage-time
   estimate is illustrative rather than a validated spoilage model.

## Key files

- `backend/server.js` — demo API, reading simulator, and trend summaries.
- `backend/public/index.html` — responsive Peo Yame web dashboard.
- `lib/main.dart` — Flutter dashboard and mobile visualizations.
- `lib/dashboard_controller.dart` — live event stream, reconnection, and screen state.
- `lib/api_service.dart` — backend HTTP requests.
- `lib/models.dart` — API response models.
- `lib/config.dart` — emulator default and saved-address normalization.

The backend uses plain HTTP, in-memory storage, and no authentication. Keep the
system on a controlled local network during demonstrations.
