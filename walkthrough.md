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

The web and mobile clients receive updates from the backend and refresh when
the event stream drops. The web login uses a prefilled six-digit sample PIN
(123456); account profiles and the four sensor rows are demo fixtures. The OTP
flow is local UI only. The dashboard breach control simulates configured-limit
alerts. The trend selector shows 24 hours, one month, or three months. Demo
startup seeds a deterministic 90-day hourly history in SQLite; newer simulated
readings are stored alongside it.

## Presentation flow

1. Sign in to the web demo using the prefilled sample PIN, then open Accounts
   and My Crops to show the local demo profile and grouped sensor fixtures.
2. Show the mobile sign-in and Accounts/My Crops screens alongside the web app.
3. Point out the configured-limit status, temperature and humidity values,
   trend range, alert history, and simulation labels.
4. Change Harvest between Maize and Tomato and show the configured limits and
   simulated reading update.
5. Trigger the demo breach and show the resulting alert in the dashboard.
6. Explain limitations: no physical sensor, real SMS, server authentication,
   account-linked sensor registry, or validated spoilage model is implemented.

## Key files

- `backend/server.js` — demo API, reading simulator, and trend summaries.
- `backend/public/index.html` — responsive Peo Yame web dashboard.
- `lib/main.dart` — Flutter dashboard and mobile visualizations.
- `lib/dashboard_controller.dart` — live event stream, reconnection, and screen state.
- `lib/api_service.dart` — backend HTTP requests.
- `lib/models.dart` — API response models.
- `lib/config.dart` — emulator default and saved-address normalization.

The backend uses plain HTTP and has no authentication. SQLite persists crop
settings and readings; some event collections remain in memory. Keep the system
on a controlled local network during demonstrations.
