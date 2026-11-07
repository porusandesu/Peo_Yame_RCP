# Peo Yame Storage Monitor

Peo Yame is a local-network demonstration app with a Flutter mobile client, a
responsive web dashboard, and a Node.js/Express backend. The backend stores
farmer accounts, crop locations, sensor assignments, crop thresholds, and
readings in SQLite. Sensor readings and trend baselines are simulated; assigned
sensor IDs are metadata and do not prove device identity. Alerts and the SMS
log are demo records, not messages sent through a carrier.

## Run the backend from source

Install Node.js 18 or newer and SQLite 3 (`sqlite3` must be on `PATH`):

```bash
cd backend
npm ci
npm run demo
```

Open <http://localhost:3000>. In demo mode the backend binds to loopback and
detected private Wi-Fi addresses so a phone on the same network can connect.
Allow the app through the computer's firewall if needed. The default database
is `backend/data/storage-monitor.sqlite`; set `DATABASE_PATH` to use another
local file. Keep database/WAL files on one host and local storage.

## Windows packaged backend

Download the `peo-yame-backend-windows` artifact from a successful
[GitHub Actions run](https://github.com/porusandesu/Peo_Yame_RCP/actions),
extract it, and launch `Peo-Yame-Backend.exe`. Its notification-area icon may
be under **Show hidden icons**. The menu can launch the web panel, restart or
shut down the backend, or exit the launcher.

## Open the demo

In demo mode, both apps show a **Demo mode** button. Press it to open the shared
account without entering login details. The account is **Mr Lesego Lefoko**
(`LLefoko@email.co.bw`). Demo mode has no PIN, password, account setup or QR
pairing. Both apps use the same demo farmer and crop assignments when they
connect to the same backend. Separate backend instances have separate databases. The Android
emulator default is `http://10.0.2.2:3000`; physical phones can use **Settings →
Backend address** to connect to the PC on the same Wi-Fi. Mobile navigation is
Overview, Trends, **My Crops**, Alerts, Settings.

Production mode retains phone verification, password login, and one-use QR
pairing. Production needs a configured SMS provider for phone verification.

## Demo behavior and limitations

- Readings and historical baselines are synthetic. The simulator can be
  replaced later with an authenticated device integration.
- The backend seeds a Botswana starter catalog of grains, pulses, oilseeds,
  vegetables, and fruits. Crop ranges are indicative room-monitoring targets;
  they are not validated spoilage thresholds. Dry-grain moisture targets are
  separate from room humidity and need a grain moisture meter. See the
  [crop package and sources](docs/BOTSWANA_CROP_STORAGE_PACKAGE.md).
- The mobile crop-quality estimate is a heuristic for Maize and Sorghum using
  ambient temperature and RH. It does not measure grain moisture or inspect
  produce. It is not a quality or shelf-life prediction.
- Production farmer account, crop-location and sensor-assignment routes require
  a seven-day bearer session. Demo mode uses a shared built-in demo farmer
  without issuing or requiring a session token. Authentication routes are
  disabled in demo mode.
- The global monitoring/reading routes are not farmer-scoped. The backend uses
  plain HTTP by default. Do not expose it to untrusted networks or use real
  credentials in this local demo.
- SMS entries are logged only; no SMS provider or physical sensor is
  connected.

For a farmer-friendly setup and monitoring path, see the suggested
[low-literacy workflow](docs/BOTSWANA_CROP_STORAGE_PACKAGE.md#suggested-low-literacy-farmer-workflow).

## Run checks

```bash
flutter test
flutter analyze --no-fatal-infos lib
(cd backend && npm test && npm run check)
```

GitHub Actions runs Flutter tests/analysis and builds a debug APK; it also runs
backend syntax/integration checks and packages the Windows backend on pushes.
See [the handoff](docs/HANDOFF.md) for the latest
verified commit, Actions run, and remaining interactive checks.

## Project documentation

- [Current architecture](docs/ARCHITECTURE.md)
- [Botswana crop storage package and workflow suggestion](docs/BOTSWANA_CROP_STORAGE_PACKAGE.md)
- [Deployment notes](backend/DEPLOYMENT.md)
- [Handoff and verification](docs/HANDOFF.md)
- [Changes and history](docs/changes-2026-11-07.md)
- [Research baseline audit](docs/BASELINE_AUDIT.md)
- [Risk register](docs/RISK_REGISTER.md)
- [Test report](docs/TEST_REPORT.md)
- [Interim-report specification snapshots](docs/interim-report-specs/README.md)
