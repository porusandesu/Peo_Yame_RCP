# Walkthrough: Flutter Storage Monitor App (Presentation Demo)

**Project**: Low-Cost IoT-Based Post-Harvest Storage Monitoring System (C7-RCP-23)  
**Client**: Flutter Android app in `Documents/storage_monitor_flutter/`  
**Backend**: Existing Node/Express demo API in `storage-demo/backend/`

---

## What was built

A Flutter user-side app that polls the same API contract as the Kotlin client:

| Endpoint | Purpose |
| --- | --- |
| `GET /api/status` | Latest reading, thresholds, breach flag |
| `GET /api/alerts` | Recent alert messages |
| `GET /api/readings/history?limit=20` | Recent readings for the demo history list |

The UI shows:

1. Green/red **status card** (normal vs threshold breached)
2. **Recent alerts** list
3. **Recent readings** history (live updates every 5 seconds)

---

## Run the demo (presentation)

### 1. Start the backend (simulated hardware)

Use system Node (`/usr/bin/node`), not Cursor’s bundled Node — `better-sqlite3` can segfault on the latter.

```bash
cd ~/storage-demo/backend
npm run demo
# equivalent: /usr/bin/node demo.js
```

This starts the Express + SQLite API **and** the ESP32/DHT22 hardware simulator (new reading every 5 seconds).

You should see the demo banner with `Web Dashboard: http://localhost:3000`.

Open the HTML dashboard at `http://127.0.0.1:3000` for a side-by-side demo. In a foreground terminal, press `h` for a heatwave breach during the presentation.

### 2. Run the Flutter app (Android emulator)

```bash
cd ~/Documents/storage_monitor_flutter
flutter run
```

Default API URL is `http://10.0.2.2:3000` (emulator → host machine).  
Configured in [`lib/config.dart`](lib/config.dart).

### 3. Build an APK

```bash
cd ~/Documents/storage_monitor_flutter
flutter build apk --debug
```

APK output:

`build/app/outputs/flutter-apk/app-debug.apk`

### 4. Physical phone (same Wi‑Fi)

1. Find your laptop LAN IP (`ip addr` or `ifconfig`).
2. Edit `lib/config.dart`:

```dart
const String apiBaseUrl = 'http://192.168.x.x:3000';
```

3. Rebuild / reinstall the app.

---

## 2–3 minute presentation script

1. **Show the dashboard** — green “Conditions normal”, live temperature/humidity updating.
2. **Point at Recent Readings** — new rows appear about every 5 seconds (mock sensor).
3. **Wait for a spike** — status turns red (“Threshold breached”) and a new alert appears under Recent Alerts.
4. **Explain the pipeline** — ESP32/DHT22 will eventually POST to the same backend; the Flutter app already consumes the real API shapes, so the UI does not need to change when hardware is wired.

---

## Files of interest

- `lib/config.dart` — base URL switch (emulator vs phone)
- `lib/models.dart` — JSON models matching the backend contract
- `lib/api_service.dart` — HTTP client
- `lib/dashboard_controller.dart` — 5-second polling
- `lib/main.dart` — dashboard UI
