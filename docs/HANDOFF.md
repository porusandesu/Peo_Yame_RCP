# Project handoff — rebuild toward `exe-work` feature parity

**Updated:** 2026-11-07 (Africa/Gaborone)
**Repository:** `/home/porusandesu/Documents/storage_monitor_flutter`
**Active branch:** `pauls-branch`
**HEAD:** `03d1870` (`Record successful GitHub verification`)
**Remote:** `origin/pauls-branch` was at the same commit before these uncommitted edits.
**Reference inventory:** `exe-work` at `c8926b7`; merge base with this branch is `65d308c`.
**Current state:** substantial, uncommitted fresh reimplementation is in progress. It has not been run through CI, committed, or pushed. Do not represent it as working until CI verifies it.

## User goal and durable constraints

The user wants the useful features of the latest `exe-work` build rebuilt on Paul’s branch while excluding its erroneous behavior/code. Earlier they explicitly said the repository/local code had fundamental login failures and instructed us to start from commit `e5fc0ca` as a skeleton, then chose Paul’s much older branch as the clean starting point. Treat `exe-work` only as a feature/behavior reference. Do not cherry-pick it, copy its implementation, or revive old authentication code. Prefer small, understandable code and use GitHub Actions for tests/builds because this computer should not run live builds. User authorized pushing changes and using CI in earlier turns; that authorization persists.

Non-negotiable behavior:

- Demo mode is a visible direct-entry option on web and mobile. It opens the home/dashboard immediately as **Mr Lesego Lefoko**, `LLefoko@email.co.bw`. No OTP, phone verification, authentication request, account creation, timeout, or QR step may block Demo mode. Demo must remain usable if backend/authentication is unavailable and must not create a signed-in farmer session.
- Farmer registration has name, Botswana phone number, and password. Do not show an email-address option on create-account screens. User previously requested phone login instead of “verify with phone”; no SMS provider or fake PIN should be presented as real verification. Supported real login is phone + password, with optional authenticator/TOTP when enabled.
- QR SSO must be backend-mediated, bidirectional, short-lived, single-use, bound to an authenticated farmer/session, and tested for replay/expiry. If web is signed in first, its QR signs the phone in. If phone is signed in first, scanning the browser QR approves web sign-in. Never place a reusable password or long-lived bearer token in QR payloads.
- Do not report fixture profiles/sensor values, simulated readings, or SMS logs as authenticated/live. Do not invent crop-quality or storage-days predictions; current target bands are indicative references only.
- Preserve the user’s request to test through GitHub Actions. Do not run local app/backend tests or builds. `git diff --check` and read-only inspection are fine. GitHub workflows currently start on branch push, so push only after reviewing the full diff and updating docs; then fix CI failures and push fixes.

## What is already verified on this branch

Commits already pushed before the current feature-parity edits:

- `2e800fd` — rebuilt demo entry and added the Botswana crop starter catalog.
- `eb603c5` — increased CI Gradle heap after Android build hit the 1 GiB limit.
- `03d1870` — recorded successful CI evidence.

GitHub Actions run `42380844326` passed backend checks/tests, Flutter widget tests, Dart analysis, Android debug APK build and artifact upload. The earlier `42380409390` failed Android packaging because Gradle exhausted a 1 GiB heap; heap is now 3 GiB. This earlier green run does **not** verify any of the current uncommitted auth/QR/tray edits.

## Current uncommitted work (inspect before changing)

`git status --short` at handoff:

```
 M .github/workflows/android-build.yml
A  Peo_Yame_logo_assets/Peo_Yame_Dev_Assets/windows/PeoYame.ico
 M README.md
 M backend/.gitignore
 M backend/DEPLOYMENT.md
 M backend/database.js
 M backend/package-lock.json
 M backend/package.json
 M backend/public/index.html
 M backend/server.js
 M docs/HANDOFF.md
 M lib/api_service.dart
 M lib/main.dart
 M macos/Flutter/GeneratedPluginRegistrant.swift
 M pubspec.lock
 M pubspec.yaml
?? backend/Stop Peo Yame.bat
?? backend/WindowsLauncher.cs
?? backend/authenticator.js
?? backend/build-windows.ps1
?? backend/farmer_auth.js
?? backend/launcher.js
?? backend/runtime_paths.js
?? backend/test/farmer-auth.test.js
?? docs/FEATURE_PARITY.md
```

`backend/vendor/sqlite3.exe` was already an untracked workspace file before this increment. It is ignored by the new backend gitignore and is user/local environment content. Do not stage, delete, overwrite, or include it. `build-windows.ps1` uses a temp SQLite CLI and deletes the temporary copied vendor CLI in its `finally` block if it created one. Keep checking `git status` before staging.

Current implementation areas:

1. **Windows backend package:** new `backend/launcher.js`, `WindowsLauncher.cs`, `Stop Peo Yame.bat`, `build-windows.ps1`, runtime path selection and Windows workflow job. Intended output is a portable ZIP with a branded WinForms system tray menu, packaged Node backend, SQLite CLI, quick-start doc, and user data under `%LOCALAPPDATA%\Peo Yame\data`. Workflow downloads SQLite, runs Windows backend tests, builds `pkg@5.8.1` Node 18 executable, compiles C# launcher, smoke-tests packaged HTTP health/dashboard/crop catalog/database, uploads artifact. Entire path is pending Windows CI and may need fixes.
2. **Backend farmer auth:** new `farmer_auth.js` and `authenticator.js`; SQLite tables for accounts, hashed/revocable seven-day sessions, one-use QR challenges, owned crop sites and sensor associations. Passwords use salted scrypt; phone normalization expects Botswana 8-digit local numbers or +267 form; login attempt limiter exists in process memory. Auth is on with `AUTH_ENABLED=true` or production. Demo mode remains separately available. Check security/error semantics carefully.
3. **Backend endpoints:** register/login/session/logout, TOTP enrollment/enable/disable, two-direction QR SSO, profile read/update, owner-scoped crop sites/sensor linking/discovery. Integration test is `backend/test/farmer-auth.test.js`. Data migrated with optional readings.sensor_id. Read server route definitions and tests before changing contracts.
4. **Flutter auth work:** `mobile_scanner` dependency; sign-in/create account screen with backend address field, no email entry, phone/password, optional TOTP; session token in SharedPreferences; QR scanner; authenticator setup; signed-in mobile can approve browser QR; signed-in web QR can be exchanged by phone. Demo still skips session auth. `ApiService` additions in `lib/api_service.dart` and UI in `lib/main.dart` are not CI-verified.
5. **Web work:** `backend/public/index.html` now wires phone/password registration and login, session restore/logout, both QR directions, profile editing, owned crop locations and discovered-sensor linking. Shared Demo has no fake owned sensor rows and its My Crops view uses the crop catalog. Review and CI verification are still required; authenticator controls and richer mobile-owned-site management remain gaps.
6. **Feature checklist:** `docs/FEATURE_PARITY.md` records the `exe-work` inventory but its status table is stale and must be updated as work lands. Keep it aligned with behavior and CI evidence.

Some latest web edits replaced the demo-only profile/sensor display and added the wired auth/site flows. The approved Sorghum brand asset package and platform icons from `exe-work` are restored, Flutter/web surfaces now use the supplied mark, and Android camera permission is present for QR scanning. Review the browser flows and complete diff before treating them as done. No local tests/builds have been run on current edits.

## Critical review issues / implementation work remaining

Do these in order, updating this handoff as tasks finish:

### 1. Reconcile backend auth/session behavior and tests

- Review `backend/server.js`, `database.js`, `farmer_auth.js`, and the entire `farmer-auth.test.js`; verify every route uses intended auth middleware and owner scoping. Confirm `AUTH_ENABLED` false in development leaves demo direct while farmer access clearly reports disabled; production auth must be usable.
- Check server health route returns `authEnabled: AUTH_ENABLED` (Flutter checks `health['authEnabled']`; integration test asserts it).
- Verify static hosting with `pkg`: `process.pkg` public path behavior may differ from `__dirname`; packaged smoke test must catch it.
- Validate expiry comparisons and atomic consumption of QR challenges, failed-login limiter behavior, duplicate registration races, invalid body handling, session revocation and DB errors. SQLite CLI uses one subprocess per statement; challenge consume/update and foreign-key behavior need integration coverage.
- Ensure one global sensor cannot be linked to multiple farmers. Current schema primary key on sensor_id prevents second ownership; check error and test it.
- Add/adjust integration cases: auth disabled but demo works without auth; wrong password; duplicate account; TOTP required/wrong/correct; session restore/logout/restart/expiry; owner isolation; sensor missing/foreign/duplicate; both QR directions; wrong auth; expired/replayed/concurrent challenges; malformed values.
- Rate limiter is in-memory and per `clientKey` (review what `clientKey` actually receives; it may be a constant/default). If ineffective per caller, fix with a small auditable strategy or document limitation; never claim production-grade security.

### 2. Review and verify the Web experience

- Gate, registration/login, `sessionStorage` restore/logout, browser QR polling, phone QR creation, profile edit, and owner-scoped site/sensor controls are wired. Review listeners, expiry cleanup, XSS-safe interpolation and failure states; CI has not yet run.
- Keep shared Demo session-free and visibly separate. Global readings/status remain shared demo telemetry, not farmer-isolated data.
- Browser TOTP setup/disable is not implemented; do not imply the browser supports account security controls it does not have.

### 3. Finish mobile feature parity

- Five destinations now appear in this order: **Overview, Trends, My Crops, Alerts, Settings**, with **My Crops in the center**. Demo catalog and crop selection work through the shared APIs; pending CI.
- Mobile farmer-owned site creation/deletion and sensor discovery/assignment/unlink still need implementation. Keep these separate from Demo's shared catalog.
- Existing scanner exchanges phone QR while signed out and approves browser QR only from authenticated phone. Verify backend URL/token preservation and scanner/client disposal. Add reverse mobile QR flow if needed by UX.
- Hook profile edit/settings to backend (or remove nonfunctional buttons). Sign-out should revoke session and clear saved token even if server unreachable.
- Check phone UI for Botswana formatting, errors, password validation, loading, keyboard behavior, saved backend address, app lifecycle, camera permission/denial and QR expiry. Demo must work even if backend check times out.
- Inspect `DashboardController` SSE and polling fallback. Add bounded retry/backoff/failure status and offline freshness/last-seen. Never present stale data as current. Avoid unrelated complexity.
- Add mobile profile edit and authenticator disable controls if required; check account destination callback indexes after navigation changes.

### 4. Windows executable/tray

- Review launcher process paths/quoting and shutdown behavior. It must start backend quietly, open dashboard, expose restart/stop/exit from notification area, clean up process on exit, preserve Local AppData, and require no Node.js/SQLite install.
- Check SQLite URL/version/extraction. Check `pkg` target/cache/network on `windows-latest`; SQLite binary extraction from pkg snapshot may depend on `process.pkg` behavior. Package smoke test should use bundled SQLite after clearing `SQLITE3_PATH`.
- Check C# compiler path/references on `windows-latest`, icon path, `Compress-Archive`, launcher path to sibling runtime exe, port binding, tray behavior and child cleanup. Smoke test should query health, dashboard, crop profiles, DB creation, then always stop child.
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
- Do not run local tests/builds. Push to `pauls-branch` (persistent user authorization), let GitHub Actions run Android + Linux backend + Windows tests/package, then inspect every job/log/artifact. Existing approved command prefixes include `git push`, `gh run list`, `gh run view`, `gh run watch`; if network is blocked, use the tool’s escalated command path.
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

The user asked for Demo completeness, parity, and the `exe-work` branding/identity reference, prioritizing stability. The current increment adds the center **My Crops** mobile tab in the five-tab order. It shows the shared crop catalog, monitoring target bands and notes; selecting a crop updates the dashboard, and adding one selects it for monitoring. Web Demo My Crops searches and selects from the same catalog and opens its add-crop flow. Both surfaces explicitly state that shared Demo has no saved farmer-owned locations or physical sensor links. Mobile Demo mode enables the breach control regardless of old preference state, and mobile can mark alerts reviewed like web. Hard-coded demo sensor/crop account rows were removed. The mobile alert view no longer estimates degradation risk; it reports configured-band breaches without predicting crop quality or storage life. Flutter widget assertions cover the tab, Demo labeling and breach action.

The approved Sorghum asset package and platform icons were restored from the reference branch. Flutter splash/header and backend web gate/header now use the supplied logo; Android, Windows and PWA icons are aligned; Android camera permission and round launcher icon are restored. Demo is labeled a shared profile rather than an authenticated account. Browser registration/login, session restore/logout, QR flows, profile edit, crop-site create/delete and discovered-sensor link/unlink are wired. The browser entry test was updated for the form and branding.

These changes are uncommitted and have not been tested or built locally. `git diff --check` passed after the edits. Current CI has not run, so mobile/web interactions and the Windows package remain unverified. The feature checklist marks this. The existing local `backend/vendor/sqlite3.exe` remains user/environment content; do not stage or alter it. Continue the stability review, then use the authorized GitHub Actions flow. Do not describe the new behavior as verified until relevant jobs pass.
