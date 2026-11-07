# Peo Yame presentation walkthrough

Peo Yame is a local-network demonstration for produce-storage monitoring. The
web dashboard and Flutter app share data through a Node.js backend. Readings
are simulated, configured crop limits are illustrative, and SMS records are
logged only. No physical sensor or carrier SMS is connected.

## Start

On the PC, run:

```bash
cd backend
npm ci
npm run demo
```

Open <http://localhost:3000>. For a physical phone, connect it to the same
Wi-Fi, sign in to the web app, choose **Connect mobile app**, then scan the
one-use QR in the Flutter app. A signed-out mobile app accepts QR sign-in only;
the QR is issued by an authenticated web session and expires after two minutes.

## Demonstration flow

1. Create or sign in to a farmer account in the web app. The local demo does
   not send SMS or reveal a demo PIN; use **Skip verification (demo)**.
2. Set an email/password after verification, or use the demo-only skip. Show
   email/password login on a later sign-in.
3. Pair the mobile app from the signed-in web dashboard and confirm both
   clients show the same farmer account and crop assignments.
4. Review Overview, Trends, the centered **My Crops** tab, Alerts, and
   Settings. Explain that sensor IDs are assigned metadata, not verified
   physical-device identities.
5. Change the active crop or trigger a demo breach. Describe status as a
   configured-limit comparison; don't present it as evidence of spoilage.
6. In Alerts, the mobile quality estimate is available only for Maize and
   Sorghum and uses ambient temperature/RH only. It is not a crop inspection,
   grain-moisture measurement, or shelf-life forecast.

## Limitations to disclose

- Reading generation and seeded trend history are synthetic.
- Alerts, incidents, and simulated SMS log entries are held in memory; they
  disappear when the backend restarts. Readings, crop data, accounts and
  assignments are stored in SQLite.
- Farmer account/crop routes require a bearer session. Global monitoring and
  sensor-ingestion routes are not farmer-scoped.
- The demo uses plain HTTP and is for a controlled network only. Do not use
  real credentials on an untrusted network.
- No hardware calibration, real SMS delivery, field pilot, or validated
  spoilage model has been established.

See the [README](README.md), [architecture](docs/ARCHITECTURE.md),
[handoff](docs/HANDOFF.md), and [test report](docs/TEST_REPORT.md) for
current commands and verification evidence.
