# Flutter phone app demo guide

This guide describes the current app in this repository. For installing
Flutter/Android SDK or building an APK, use the official Flutter setup steps
and the repository's GitHub Actions workflow; this file focuses on connecting
the running app to the demo backend.

## Prerequisites

- Node.js 18 or newer.
- SQLite 3 CLI available as `sqlite3` on `PATH`.
- Flutter stable and Android SDK for local app builds.
- PC and physical phone on the same Wi-Fi network. Android emulator uses
  `http://10.0.2.2:3000` by default.

## Start the backend

```bash
cd backend
npm ci
npm run demo
```

Open <http://localhost:3000> on the PC. Allow Peo Yame through the firewall if
the phone cannot reach the server. Demo mode binds to loopback and discovered
private Wi-Fi addresses.

## Sign in and connect

1. Create/sign in to the farmer account on the web page. Demo mode has no SMS
   provider, so request phone verification and select **Skip verification
   (demo)**. The server does not return or display a temporary PIN.
2. Add an email and password to enable email/password sign-in, or skip that
   step in demo mode. Existing credentials can be used directly from the web
   login form. Google Authenticator is an optional alternative.
3. Sign in to the web app, open its menu, and choose **Connect mobile app**.
4. In the signed-out Flutter app, choose **Scan sign-in QR** and scan the
   displayed one-use QR. The QR challenge expires after two minutes and is
   consumed once. The mobile app does not provide OTP login, account creation,
   or manual backend-address entry on its signed-out screen.

The QR is generated only after an authenticated web session. This ensures a
person who can merely view the login page cannot issue a mobile sign-in QR.
Both clients share accounts and crop assignments only when connected to the
same running backend.

## What the demo shows

The five mobile tabs are Overview, Trends, My Crops, Alerts, and Settings;
My Crops is the center tab. Readings and histories are simulated. Farmer crop
locations and sensor assignments persist in SQLite, but assigned sensor IDs
are not hardware-authenticated. Alert/SMS log entries are simulated, and no
carrier message is sent. Keep the backend on a controlled local network; its
default HTTP transport is not suitable for untrusted networks.

See [README.md](README.md), [backend/DEPLOYMENT.md](backend/DEPLOYMENT.md),
and [docs/HANDOFF.md](docs/HANDOFF.md) for current build and test details.
