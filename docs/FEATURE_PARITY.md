# Feature parity plan from `exe-work`

**Baseline reviewed:** `exe-work` at `c8926b7` on 2026-11-07. This is a
behavior inventory. It does not authorize copying that branch's implementation.
Items below are being rebuilt against the current `pauls-branch` code and must
be covered by current CI before being called complete.

## Features to retain or rebuild

| Area | Behavior from the reference build | Current `pauls-branch` status |
|---|---|---|
| Demo access | One tap opens the dashboard as Mr Lesego Lefoko (`LLefoko@email.co.bw`) on web and mobile; no login, verification, or QR step | Implemented; session-free, pending restore races are guarded, and mobile demo controls are enabled independently of saved preferences; widget assertions added, pending CI |
| Farmer sign-in | Mobile uses a Botswana phone number; signed-in sessions can be restored and explicitly logged out | Backend and Flutter screens/API are implemented; session persistence and sign-out are not CI-verified |
| Web account access | Farmer can create an account and sign in from the browser; profile details can be managed | Registration/login, session restore/logout and profile edit are wired to the backend; pending CI |
| Account security | Passwords are salted/hashed, server sessions are revocable/expiring, and authenticator app setup is verified before enablement | Backend scrypt/TOTP and session routes exist; Flutter can enable TOTP; disable flow, expiry/lockout cases and security review remain |
| Cross-device sign-in | Authenticated web can issue a one-use QR to connect a phone; an authenticated phone can approve a one-use QR for browser sign-in | Backend challenges and web polling/mobile scanning are wired both ways; replay covered by integration test, expiry/concurrency and client flows pending CI |
| Crop/site management | Farmers can save named crop/storage locations against their own account | Owner-scoped backend and browser create/delete views implemented; mobile still needs owned-site management; pending CI |
| Sensor assignment | Farmer can discover/register sensor IDs and assign/unassign them to storage locations; ownership is server checked | Owner-scoped backend and browser discovery/link/unlink views implemented; mobile still needs sensor management; pending CI |
| Mobile navigation | Overview, Trends, My Crops, Alerts, Settings; My Crops is the center destination | Five destinations implemented in requested order; My Crops shows the shared crop catalog, target bands and notes; account screen no longer shows fixture sensor/crop rows; Demo explicitly has no owned sites or physical sensor records; pending CI |
| Demo crop catalog | Web and mobile expose the same catalog, monitoring bands and crop notes; selecting a crop updates the shared demo dashboard | Web catalog view now supports search/selection and adding a catalog crop; mobile center tab supports crop notes, selection and adding a catalog crop; pending CI |
| Demo alert lifecycle | Demo breach produces a visible alert on both clients and users can mark alerts reviewed | Both clients expose the demo breach control; web already supports review, mobile now calls the same acknowledge endpoint; pending CI |
| Reconnect behavior | Event stream reconnects, polling provides fallback, and stale/offline state appears after repeated failures | SSE reconnect and 30-second fallback polling exist; failure threshold/last-seen behavior is incomplete |
| Windows backend | Portable Windows ZIP; branded GUI launcher starts backend and exposes dashboard/restart/stop/exit from the notification-area menu | Reimplementation and Windows CI job added; packaged build pending CI; startup now opens dashboard |
| Branding and identity | Approved Sorghum Peo Yame logo and consistent Mr Lesego Lefoko shared Demo profile across mobile and web; branded Android, Windows, and web icons | Reference brand asset package restored; Flutter splash/header and backend web gate/header use the logo; Android adaptive/round launcher icons, Windows icon, and PWA icons match the reference; Demo is labeled a shared profile rather than an authenticated account; pending CI |
| Crop starter data | Botswana-relevant grains, pulses, oilseeds, fruits, and vegetables with limits and notes | 24-profile SQLite package implemented; targets documented as indicative |
| Build delivery | CI tests Flutter, backend on Linux and Windows, Android package, and Windows executable | Linux checks/Android pass; Windows job newly added and pending |

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
