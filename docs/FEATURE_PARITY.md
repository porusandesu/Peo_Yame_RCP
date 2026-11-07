# Feature parity plan

**Baseline:** verified rebuild now lives on `exe-work` (ported from
`pauls-branch`). Status below is for the current `exe-work` tip and must stay
honest about CI vs device-level checks.

## Features to retain or rebuild

| Area | Target behavior | Current `exe-work` status |
|---|---|---|
| Demo access | One tap opens the dashboard as Mr Lesego Lefoko (`LLefoko@email.co.bw`) on web and mobile; no login, verification, or QR step | Implemented; shared and session-free. Flutter widget test and web/backend demo-entry checks pass. Demo controls initialize immediately. |
| Farmer sign-in | Mobile uses a Botswana phone number; signed-in sessions can be restored and explicitly logged out | Backend integration suite covers register/login/session/logout. Device-level session restore/sign-out remains unverified. |
| Web/mobile account access | Farmer can create an account and sign in from the browser or mobile; profile name and optional email are editable | Both clients edit name and optional email through the owner-authenticated account endpoint. Create-account screens do not offer email as a sign-in identity. |
| Account security | Passwords are salted/hashed, server sessions are revocable/expiring, and authenticator app setup is verified before enablement | Backend, mobile, and web expose setup/enable/disable. Integration coverage includes missing/wrong/correct TOTP. Independent security review remains. |
| Cross-device sign-in | Authenticated web can issue a one-use QR to connect a phone; an authenticated phone can approve a one-use QR for browser sign-in | Both QR directions are implemented. Integration coverage includes reuse, concurrent approve, and expiry. Physical camera flow remains unverified. |
| Crop/site management | Farmers can save named crop/storage locations against their own account and find them by crop, location or sensor ID | Both clients create/delete owner-scoped locations through the same backend APIs. |
| Sensor assignment | Farmer can discover/register sensor IDs and assign/unassign them to storage locations; ownership is server checked | Both clients link only observed sensor IDs. Duplicate global ownership returns 409 and is covered by integration tests. |
| Mobile navigation | Overview, Trends, My Crops, Alerts, Settings; My Crops is the center destination | CI widget test confirms the Demo dashboard and destination order. |
| Settings, account access and alert evidence | Both clients expose refresh, exports and account security where signed in; mobile Settings groups Profile first and Accounts actions beneath it | Mobile Settings is the only path to profile/account controls. Web Settings includes account/security status. Mobile Alerts shows the simulated dispatch log with a not-sent disclosure. |
| Demo crop catalog | Web and mobile expose the same catalog, monitoring bands and crop notes; selecting a crop updates the shared demo dashboard | Both clients use the backend catalog. No live sensor is attached in Demo. |
| Demo alert lifecycle | Demo breach produces a visible alert on both clients and users can mark alerts reviewed | Both clients expose the breach control and acknowledgement action. |
| Cross-app data sync | Web and mobile observe the same readings, active crop, alerts, and farmer-owned account changes from one backend | Both clients subscribe to the same server-sent update stream; mobile polling is the fallback. |
| Reconnect behavior | Event stream reconnects, polling provides fallback, and stale/offline state appears after repeated failures | SSE reconnect uses bounded backoff. Polling falls back every 30s. Offline UI appears after two consecutive failures and labels last-known readings instead of presenting them as live. |
| Windows backend | Portable Windows ZIP; branded GUI launcher starts backend and exposes dashboard/restart/stop/exit from the notification-area menu | Windows CI package smoke test and artifact upload pass. Interactive tray behavior still needs a Windows desktop check. |
| Branding and identity | Approved Sorghum Peo Yame logo and consistent Mr Lesego Lefoko shared Demo profile across mobile and web | Brand assets and platform icons are in the build. Visual appearance has not been reviewed on physical devices. |
| Crop starter data | Botswana-relevant grains, pulses, oilseeds, fruits, and vegetables with limits and notes | 24-profile SQLite package implemented; targets documented as indicative |
| Build delivery | CI tests Flutter, backend on Linux and Windows, Android package, and Windows executable | Port commit `8a84056` CI run `42405581867` passed. Follow-up offline/auth hardening awaits the next green run. |

## Failure behavior deliberately excluded

- Demo buttons must never request OTP, wait on a verification endpoint, create a
  token, or depend on backend authentication availability.
- Never display a fixed/example PIN as if it proves phone ownership. A real OTP
  requires a configured delivery provider; otherwise the UI must say the method
  is unavailable and offer a usable supported sign-in method.
- QR challenges must be random, short-lived, single-use, tied to a verified
  account/session, and rejected after expiry or use. QR payloads must not embed
  reusable account passwords or long-lived bearer tokens.
- Do not treat browser-local profile data, global active-crop state, fixture
  sensor rows, stale readings, or simulated SMS logs as authenticated/live data.
- Do not show crop-quality or remaining-storage-day predictions without a
  validated model and evidence.

## Rebuild order

1. Finish and CI-verify the Windows package before relying on it for demos.
2. Implement persistent farmer/session/site/sensor ownership and isolated API
   authorization, with direct demo mode remaining separate and session-free.
3. Implement supported phone/web sign-in and authenticator setup, then test
   success, wrong credentials, lockout, session expiry, logout, and restart.
4. Implement and integration-test both QR directions, including wrong-account,
   expired, reused, and concurrent challenge cases.
5. Connect crop/sensor screens to owned backend records; add five-tab navigation
   and clear offline/last-seen messaging.
6. Add the app/web brand assets and test the Android and Windows artifacts in
   GitHub Actions. Record each run and artifact in the handoff.
