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

## Sign in and pair the mobile app

1. Create a farmer account on the web app using a phone number. The local demo
   does not send SMS; after requesting phone verification, choose **Skip
   verification (demo)**. The PIN is not returned or shown.
2. Add an email and password to secure the account. Demo mode lets you skip
   this step; accounts with credentials can sign in on the web using them.
   Phone verification/Google Authenticator remains available as an alternate
   sign-in path.
3. To sign in on mobile, first sign in on the web app. Choose **Connect mobile
   app**, then scan the one-use QR in the mobile app. It expires after two
   minutes. The signed-out mobile app accepts QR pairing only; it has no phone
   OTP or manual backend-connection flow.

Both clients use the same SQLite-backed farmer account when they connect to
the same running backend. Separate backend instances have separate databases.
The Android emulator default is `http://10.0.2.2:3000`; physical phones should
use the web pairing QR. Mobile navigation is Overview, Trends, **My Crops**,
Alerts, Settings.

## Demo behavior and limitations

- Readings and historical baselines are synthetic. The simulator can be
  replaced later with an authenticated device integration.
- Maize, Sorghum, and Tomato are seeded crop profiles; their configured limits
  are demo values, not validated spoilage thresholds.
- The mobile crop-quality estimate is a heuristic for Maize and Sorghum using
  ambient temperature and RH. It does not measure grain moisture or inspect
  produce. It is not a quality or shelf-life prediction.
- Farmer account, crop-location and sensor-assignment routes require a
  seven-day bearer session. Session tokens are hashed in SQLite; passwords are
  stored as salted scrypt hashes. Demo verification and demo credential-skip
  are disabled in production mode.
- The global monitoring/reading routes are not farmer-scoped. The backend uses
  plain HTTP by default. Do not expose it to untrusted networks or use real
  credentials in this local demo.
- SMS entries are logged only; no SMS provider or physical sensor is
  connected.

## Run checks

```bash
flutter test
dart analyze lib
cd backend && npm test
```

GitHub Actions builds a debug APK and runs the Windows backend test/package
job on pushes to the branch. See [the handoff](docs/HANDOFF.md) for the latest
verified commit, Actions run, and remaining interactive checks.

## Project documentation

- [Current architecture](docs/ARCHITECTURE.md)
- [Deployment notes](backend/DEPLOYMENT.md)
- [Handoff and verification](docs/HANDOFF.md)
- [Changes and history](docs/changes-2026-11-07.md)
- [Research baseline audit](docs/BASELINE_AUDIT.md)
- [Risk register](docs/RISK_REGISTER.md)
- [Test report](docs/TEST_REPORT.md)
- [Interim-report specification snapshots](docs/interim-report-specs/README.md)
