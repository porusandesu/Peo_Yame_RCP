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

Open <http://localhost:3000> and choose **Demo mode → Open demo home**. On the
phone, connect to the same Wi-Fi, open the mobile app and tap **Demo mode**. Both
clients enter as **Mr Lesego Lefoko** (`LLefoko@email.co.bw`) without requesting
login details. Use **Settings → Backend
address** if the phone is pointed at a different backend. The demo has no
sign-in, verification, password, logout or QR pairing flow.

## Demonstration flow

1. Confirm both clients show the demo profile and enter the dashboard with one
   tap, without prompting for credentials.
2. Add a crop location in **My Crops** and confirm both clients see it when
   connected to the same backend.
3. Review Overview, Trends, the centered **My Crops** tab, Alerts, and
   Settings. Explain that sensor IDs are assigned metadata, not verified
   physical-device identities.
4. In **My Crops**, add a crop. The web and mobile selectors group the starter
   catalog into grains, pulses, oilseeds, vegetables and fruits. Explain the
   selected room target; dry-grain moisture is a separate value that requires
   a grain moisture meter.
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
- Demo farmer/crop routes use the shared Demo Farmer without a bearer session;
  production farmer routes require a session. Global monitoring and sensor
  ingestion routes are not farmer-scoped.
- The demo uses plain HTTP and is for a controlled network only. Do not use
  real credentials on an untrusted network.
- No hardware calibration, real SMS delivery, field pilot, or validated
  spoilage model has been established.
- The crop storage ranges are starter references and have not been validated
  with local cultivars, storage facilities or Botswana extension officers.
- The low-literacy workflow in the crop package is a design recommendation,
  not a field-tested feature set.

See the [README](README.md), [architecture](docs/ARCHITECTURE.md),
[handoff](docs/HANDOFF.md), and [test report](docs/TEST_REPORT.md) for
current commands and verification evidence.
