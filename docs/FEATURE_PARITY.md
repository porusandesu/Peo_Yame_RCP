# Feature parity plan from `exe-work`

**Baseline reviewed:** `exe-work` at `c8926b7` on 2026-11-07. This is a
behavior inventory. It does not authorize copying that branch's implementation.
Items below are being rebuilt against the current `pauls-branch` code and must
be covered by current CI before being called complete.

## Features to retain or rebuild

| Area | Behavior from the reference build | Current `pauls-branch` status |
|---|---|---|
| Demo access | One tap opens the dashboard as Mr Lesego Lefoko (`LLefoko@email.co.bw`) on web and mobile; no login, verification, or QR step | Implemented; shared and session-free. Flutter widget test and web/backend demo-entry checks pass in run `42388143703`. Demo controls initialize immediately and ignore saved demo preferences. |
| Farmer sign-in | Mobile uses a Botswana phone number; signed-in sessions can be restored and explicitly logged out | Backend integration suite passes on Linux and Windows; Flutter compiles. Device-level session restore/sign-out remains unverified. |
| Web account access | Farmer can create an account and sign in from the browser; profile details can be managed | Backend auth integration suite passes on Linux and Windows; web entry static check passes. Browser interaction is not automated end-to-end. |
| Account security | Passwords are salted/hashed, server sessions are revocable/expiring, and authenticator app setup is verified before enablement | Backend auth integration suite passes. Flutter TOTP setup is implemented. TOTP disable, broader expiry/lockout review and independent security review remain. |
| Cross-device sign-in | Authenticated web can issue a one-use QR to connect a phone; an authenticated phone can approve a one-use QR for browser sign-in | QR actions are now available in mobile Accounts as well as web Accounts/sign-in. Codes carry a validated backend origin so a second phone can connect to the same backend; scanner confirms switching backends. CI coverage added, pending run. Physical camera flow remains unverified. |
| Crop/site management | Farmers can save named crop/storage locations against their own account | Owner-scoped backend and browser create/delete views implemented and backend suite passes; mobile owned-site management remains a gap. |
| Sensor assignment | Farmer can discover/register sensor IDs and assign/unassign them to storage locations; ownership is server checked | Owner-scoped backend and browser discovery/link/unlink views implemented and backend suite passes; mobile sensor management remains a gap. |
| Mobile navigation | Overview, Trends, My Crops, Alerts, Settings; My Crops is the center destination | CI widget test confirms the Demo dashboard, center crop tab, shared catalog and Alerts control. Five destinations are in the requested order. |
| Demo crop catalog | Web and mobile expose the same catalog, monitoring bands and crop notes; selecting a crop updates the shared demo dashboard | Both clients use the backend catalog. Web supports search/selection and adding a catalog crop; mobile supports notes, selection and adding a crop. Backend and Flutter CI pass; no live sensor is attached in Demo. |
| Demo alert lifecycle | Demo breach produces a visible alert on both clients and users can mark alerts reviewed | Both clients expose the breach control and acknowledgement action. Backend integration and Flutter widget CI pass; client-to-live-backend alert behavior was not exercised end-to-end. |
| Cross-app data sync | Web and mobile observe the same readings, active crop, alerts, and farmer-owned account changes from one backend | Both clients subscribe to the same server-sent update stream and refresh shared snapshots; 30-second polling is the fallback. Backend broadcasts now identify crop selection, alert review, and farmer-account changes; integration coverage checks that two clients receive the same event and data. CI pending. |
| Reconnect behavior | Event stream reconnects, polling provides fallback, and stale/offline state appears after repeated failures | SSE reconnect and 30-second fallback polling exist; failure threshold/last-seen behavior is incomplete |
| Windows backend | Portable Windows ZIP; branded GUI launcher starts backend and exposes dashboard/restart/stop/exit from the notification-area menu | Windows CI package smoke test and artifact upload pass in run `42388143703`. Interactive tray behavior still needs a Windows desktop check. |
| Branding and identity | Approved Sorghum Peo Yame logo and consistent Mr Lesego Lefoko shared Demo profile across mobile and web; branded Android, Windows, and web icons | Brand assets and platform icons are in the build; Flutter analyze/APK build and Windows package pass. Visual appearance has not been reviewed on physical devices. |
| Crop starter data | Botswana-relevant grains, pulses, oilseeds, fruits, and vegetables with limits and notes | 24-profile SQLite package implemented; targets documented as indicative |
| Build delivery | CI tests Flutter, backend on Linux and Windows, Android package, and Windows executable | Run `42388143703` passes Flutter widget tests, Dart analysis, Android APK, Linux/Windows backend suites and Windows package smoke test. |

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
