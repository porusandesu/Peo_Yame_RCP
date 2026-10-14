# Storage Monitor Demo — Setup

Two parts: a **backend** (mock sensor data) and an **Android app** that displays it live.

## 1. Run the backend

```
cd backend
npm install
npm start
```

You should see `Storage monitor demo API running on http://0.0.0.0:3000`.
It generates a new reading every 5 seconds and raises an alert automatically
when one breaches the threshold (happens ~15% of the time, so you'll see
alerts within a minute or two of running it).

Test it's alive by visiting `http://localhost:3000/api/status` in a browser.

## 2. Open the Android app

1. Open Android Studio → **Open** → select the `android-app` folder.
2. Let Gradle sync (first time will download dependencies — needs internet).
3. Check `RetrofitClient.kt` — the base URL is already set for the emulator
   (`10.0.2.2`). If you're running on a **physical phone**, replace it with
   your laptop's LAN IP instead (same WiFi network required).
4. Run the app (▶ button) on an emulator or your phone.

You should see live temperature/humidity, a green/red status card, and an
alerts list that updates every 5 seconds.

## 3. When the real database/API is ready

Replace the mock logic in `backend/server.js` with real queries — the route
shapes (`/api/status`, `/api/readings/history`, `/api/alerts`) are designed
to match your ER diagram (readings, thresholds, alerts), so the Android app
won't need any changes at all once the real data source is swapped in.
