# Project handoff — verified fixes on `exe-work`

**Updated:** 2026-11-07 (Africa/Gaborone)
**Repository:** `/home/porusandesu/Documents/storage_monitor_flutter`
**Active branch:** `exe-work`
**Prior user base:** `43773e1` (`Add QR sign-in and account management actions`)
**Prior `exe-work` tip before this port:** `c8926b7`
**Source of verified fixes:** `pauls-branch` at `467e847` (rebuilt after `exe-work` login/OTP failures)
**Current state:** The working demo, phone/password auth, QR SSO, branding, web/mobile parity, and Windows package from `pauls-branch` are now on `exe-work`. Old OTP request/skip-demo-verification paths from the post-`43773e1` `exe-work` line are removed. Port commit `8a84056` CI run `42405581867` passed. Current worktree hardens offline freshness, login client-key throttling, and auth edge-case tests. Physical-device camera, live-sensor, and interactive tray checks remain unverified.

## User goal and durable constraints

The useful features attempted after `43773e1` on `exe-work` (demo entry, farmer accounts, QR SSO, Windows tray, branding, crop/sensor ownership) are retained. The broken OTP/demo-skip login path from that line is not. Prefer small, understandable code and use GitHub Actions for tests/builds because this computer should not run live builds. User authorized pushing changes and using CI in earlier turns; that authorization persists.

Non-negotiable behavior:

- Demo mode is a visible direct-entry option on web and mobile. It opens the home/dashboard immediately as **Mr Lesego Lefoko**, `LLefoko@email.co.bw`. No OTP, phone verification, authentication request, account creation, timeout, or QR step may block Demo mode. Demo must remain usable if backend/authentication is unavailable and must not create a signed-in farmer session.
- Farmer registration has name, Botswana phone number, and password. Do not show an email-address option on create-account screens. User previously requested phone login instead of “verify with phone”; no SMS provider or fake PIN should be presented as real verification. Supported real login is phone + password, with optional authenticator/TOTP when enabled.
- QR SSO must be backend-mediated, bidirectional, short-lived, single-use, bound to an authenticated farmer/session, and tested for replay/expiry. If web is signed in first, its QR signs the phone in. If phone is signed in first, scanning the browser QR approves web sign-in. Never place a reusable password or long-lived bearer token in QR payloads.
- Do not report fixture profiles/sensor values, simulated readings, or SMS logs as authenticated/live. Do not invent crop-quality or storage-days predictions; current target bands are indicative references only.
- Preserve the user’s request to test through GitHub Actions. Do not run local app/backend tests or builds. `git diff --check` and read-only inspection are fine. GitHub workflows currently start on branch push, so push only after reviewing the full diff and updating docs; then fix CI failures and push fixes.

## What is already verified on this branch

Base commits before the latest work:

- `2e800fd` — rebuilt demo entry and added the Botswana crop starter catalog.
- `eb603c5` — increased CI Gradle heap after Android build hit the 1 GiB limit.
- `03d1870` — recorded successful CI evidence.

Latest completed verification: [42389614438](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42389614438), at documentation commit `8854ce0a34b4ee53cd64e81aead1cc3d2f3769b3`, passed on rerun attempt 2. Attempt 1 hit an Android SDK NDK archive unpack error; retry passed without source changes. Backend tests/syntax checks passed on Linux and Windows; the Windows package smoke test and upload passed; Flutter widget tests, Dart analysis, Android APK build and upload passed. Artifacts: `storage-monitor-android-debug` expires 2026-11-21; `peo-yame-backend-windows` expires 2026-12-07. CI does not verify physical-device camera use, device visuals, live sensor connectivity, SMS delivery, or full browser/mobile auth interaction.

## Current implementation (inspect before changing)

The handoff implementation is committed and pushed. `backend/vendor/sqlite3.exe` is ignored user/environment content. Do not stage, delete, overwrite, or include it. `build-windows.ps1` uses a temp SQLite CLI and cleans up any temporary copy it creates. Keep checking `git status` before staging.

Current implementation areas:

1. **Windows backend package:** `backend/launcher.js`, `WindowsLauncher.cs`, `Stop Peo Yame.bat`, `build-windows.ps1`, runtime path selection and Windows workflow job create a portable ZIP with a branded WinForms tray menu, packaged Node backend, SQLite CLI, quick-start doc, and user data under `%LOCALAPPDATA%\Peo Yame\data`. CI packages and smoke-tests HTTP health/dashboard/crop catalog/database and uploads the ZIP. Interactive tray behavior still needs a Windows desktop check.
2. **Backend farmer auth:** new `farmer_auth.js` and `authenticator.js`; SQLite tables for accounts, hashed/revocable seven-day sessions, one-use QR challenges, owned crop sites and sensor associations. Passwords use salted scrypt; phone normalization expects Botswana 8-digit local numbers or +267 form; login attempt limiter exists in process memory. Auth is on with `AUTH_ENABLED=true` or production. Demo mode remains separately available. Check security/error semantics carefully.
3. **Backend endpoints:** register/login/session/logout, TOTP enrollment/enable/disable, two-direction QR SSO, profile read/update, owner-scoped crop sites/sensor linking/discovery. Integration test is `backend/test/farmer-auth.test.js`. Data migrated with optional readings.sensor_id. Read server route definitions and tests before changing contracts.
4. **Flutter auth work:** `mobile_scanner` dependency; phone/password screens, optional TOTP setup, session persistence, QR scanning and browser approval. CI widget tests, analysis and Android APK build pass; physical camera and interactive session persistence remain unverified.
5. **Web work:** `backend/public/index.html` wires phone/password registration/login, session restore/logout, both QR directions, profile edit, owned crop locations and sensor linking. Backend and static-entry checks pass; browser end-to-end interaction remains unverified. Browser TOTP controls and richer mobile-owned-site management remain gaps.
6. **Feature checklist:** `docs/FEATURE_PARITY.md` records current verified paths and known gaps. Update it with future changes and new CI evidence.

The approved Sorghum brand asset package and platform icons from `exe-work` are restored, Flutter/web surfaces use the supplied mark, and Android camera permission is present for QR scanning. Demo remains visibly shared and separate from authenticated accounts. CI passes; local tests/builds were not run.

## Critical review issues / implementation work remaining

Do these in order, updating this handoff as tasks finish:

### 1. Reconcile backend auth/session behavior and tests

- Auth routes use `requireFarmer` / `AUTH_ENABLED` gating; health returns `authEnabled`.
- Integration coverage now includes duplicate sensor ownership (409), missing/wrong/correct TOTP, expired QR, concurrent approve, and replay rejection.
- Login throttling keys on `loginClientKey(req)` (`req.ip`, or first `X-Forwarded-For` hop when `TRUST_PROXY=true`). Remains process-local; documented in `backend/DEPLOYMENT.md`.
- Packaged Windows health/dashboard/crop smoke test passed in run `42405581867`. This is not an independent security audit.

### 2. Review and verify the Web experience

- Gate, registration/login, session restore/logout, both QR directions, profile edit, TOTP setup/disable, and owner-scoped site/sensor controls are wired with escaped HTML interpolation.
- Shared Demo stays session-free and visibly separate. Global readings remain shared demo telemetry.
- Browser interactive acceptance is still outstanding.

### 3. Finish mobile feature parity

- Five destinations: **Overview, Trends, My Crops, Alerts, Settings** with My Crops centered.
- Owned site/sensor management, profile edit, authenticator setup/disable, and Accounts QR flows are implemented.
- `DashboardController` now uses a two-failure offline threshold, records `lastSuccessfulAt`, labels last-known readings when offline, and applies bounded SSE reconnect backoff.
- Sign-out clears the saved token even if the server is unreachable.
- Physical camera, permission denial, and live-sensor connectivity remain unverified.

### 4. Windows executable/tray

- Review launcher process paths/quoting and shutdown behavior. It must start backend quietly, open dashboard, expose restart/stop/exit from notification area, clean up process on exit, preserve Local AppData, and require no Node.js/SQLite install.
- Check SQLite URL/version/extraction and `pkg` resource paths. Packaged health/dashboard/crop/database smoke test passed; continue to review cleanup paths.
- CI verified C# compilation, icon/package paths, launcher paths, port binding, health/dashboard/crop responses and database creation. Interactive tray behavior and child cleanup still need a Windows desktop check.
- Package must not include credentials/secrets/user DB. `backend/vendor` and `backend/dist` should be ignored; never commit local vendor binary.
- Quick start should explain private-network firewall and local dashboard without claiming unshipped features.

### 5. Docs and evidence

- Update `docs/FEATURE_PARITY.md` status per feature only after code and CI verify; mark gaps honestly.
- Update README/`backend/DEPLOYMENT.md` to actual instructions and production caveats. Preserve Botswana crop reference limits/caveats.
- Add Windows/auth/QR/API usage and limitations. Do not promise SMS verification; there is no provider.
- Append exact GitHub run URL, commit, job conclusions, artifact and expiry to `docs/TEST_REPORT.md` and this handoff after green CI.
- Keep this handoff current at each meaningful stopping point: commit, changed files, evidence, failures, remaining task sequence, vendor note.

### 6. CI, commit and push

- After implementation review, inspect `git diff --check`, `git status --short`, full diff in chunks; ensure old `backend/vendor/sqlite3.exe` is not staged.
- Do not run local tests/builds. Push to `exe-work` (user-authorized), let GitHub Actions run Android + Linux backend + Windows tests/package, then inspect every job/log/artifact. Existing approved command prefixes include `git push`, `gh run list`, `gh run view`, `gh run watch`; if network is blocked, use the tool’s escalated command path.
- Fix failures and push corrections. Don’t stop at Linux pass if Windows is red; the Windows executable/tray is a product requirement.
- Commit only coherent reviewed changes and avoid committing user/local files.

## Expected next-session start

```sh
cd /home/porusandesu/Documents/storage_monitor_flutter
git status --short
git log -4 --oneline
git diff --check
```

Read this file, `docs/FEATURE_PARITY.md`, `docs/TEST_REPORT.md`, then inspect worktree diffs. Do not reset/discard anything or assume the previous assistant completed the plan. Continue editing in place. Verify by pushing reviewed changes and inspecting GitHub Actions; do not build locally.

## Reference checklist

`docs/FEATURE_PARITY.md` has the detailed inventory from `exe-work`. In brief: direct shared demo; phone/password accounts; optional real TOTP; web↔phone QR SSO; farmer-owned crop/storage sites and sensor assignment; five-tab mobile navigation; reconnect/offline freshness; Botswana storage catalog; web/mobile/Windows branding; Windows portable backend executable with tray; CI-built Android/Windows artifacts. Retain useful behavior, not old implementation code.

## 2026-11-07 continuation note

The user asked for Demo completeness, parity, and the `exe-work` branding/identity reference, prioritizing stability. The increment adds the center **My Crops** tab; it presents the shared crop catalog, target bands and notes. Selecting or adding a crop updates the monitored target. Web Demo supports catalog search/selection and adding crops. Both clients say shared Demo has no saved farmer-owned locations or physical sensor links. Demo controls initialize immediately regardless of saved preferences. Mobile alerts can be acknowledged like web. Hard-coded demo sensor/crop account rows were removed, and the alert view avoids crop-quality/storage-life predictions. The Flutter widget assertion, Dart analysis and Android APK build pass in CI.

The approved Sorghum asset package and platform icons were restored from the reference branch. Flutter splash/header and backend web gate/header now use the supplied logo; Android, Windows and PWA icons are aligned; Android camera permission and round launcher icon are restored. Demo is labeled a shared profile rather than an authenticated account. Browser registration/login, session restore/logout, QR flows, profile edit, crop-site create/delete and discovered-sensor link/unlink are wired. The browser entry test was updated for the form and branding.

The application changes are committed at `8c60742`; the documentation update is `8854ce0`. CI run `42389614438` passes on rerun attempt 2 and uploaded Android and Windows artifacts. Local tests/builds were not run. Device-level visual, camera, live-sensor and complete browser/mobile interaction checks remain outstanding. The existing local `backend/vendor/sqlite3.exe` remains user/environment content; do not stage or alter it. Continue from the gaps in `docs/FEATURE_PARITY.md` and this handoff.

## 2026-11-07 sync and Accounts QR follow-up

The user asked that web/mobile reflect the same backend data at the same time and that Accounts expose a sign-in QR. The clients already use one backend and listen to its SSE update stream; the mobile controller keeps polling as a fallback. This follow-up names selection, alert-review and account changes in the stream, makes the browser reload owner-scoped account data on those events, and adds integration assertions for two simultaneous clients receiving matching update IDs and snapshots. The mobile Accounts screen now offers a one-use QR for another phone and a scanner action to approve browser sign-in. QR payloads can carry a validated backend origin, and the scanner confirms a backend switch before exchanging a mobile sign-in code. CI run [42391735676](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42391735676) passed on commit `5a61725`; backend/Linux and Windows integration checks, Flutter tests/analysis, Android APK and Windows package jobs all passed. Device camera/visual checks and the documented mobile crop/sensor management gap remain.

## 2026-11-07 mobile crop and sensor management

The mobile My Crops view now loads farmer-owned storage locations, adds a crop/location from the shared catalog, and deletes a location with confirmation. It lists linked sensor IDs and their last reading timestamps, links only IDs detected from actual backend sensor readings to an owned location, and supports unlinking. The Accounts page routes My Crops and Manage linked sensors to this panel. Mobile reloads owner data on `account` SSE updates; polling remains the dashboard fallback. Backend tests cover owned deletion, unlink, and sensor rediscovery after unlink; Flutter coverage exercises Accounts navigation. CI run [42393553982](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42393553982) passed on `ac91aee`: backend Linux/Windows, Flutter tests/analysis, Android APK and Windows package all passed. Artifacts: Android expires 2026-11-21 and Windows expires 2026-12-07. Physical sensor connectivity and device-level visuals remain unverified.

## 2026-11-07 mobile profile edit

Authenticated farmers can edit their name from Accounts or Settings. The app saves through `PATCH /api/account`, retains the backend's account email/phone and updates the displayed profile name only after a successful response. Demo remains read-only. Flutter navigation and the backend profile-update assertion pass in run `42394803726`; no local tests/builds were run.
