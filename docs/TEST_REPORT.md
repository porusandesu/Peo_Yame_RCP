# Verification record

> **Current validation (7 Nov 2026):** Demo auth removal, the crop package and
> build path now have local automated coverage. CI for the current worktree is
> pending push; physical-device and live-farmer usability checks remain open.

**Updated:** 7 November 2026
**Branch:** `exe-work`
**Code commit:** `e2161c6` (`Improve farmer sign-in and center mobile crops tab`)
**Actions:** [run 42360332399](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42360332399)

## Current worktree validation

| Check | Result | Evidence |
|---|---|---|
| Flutter widget test | Pass | Fresh demo entry shows Demo Farmer and no sign-in/QR/OTP actions. |
| Flutter analysis | Pass with infos | `flutter analyze --no-pub --no-fatal-infos lib`; 22 style/context informational notices. |
| Android debug build | Pass | `flutter build apk --debug --no-pub`; APK at `build/app/outputs/flutter-apk/app-debug.apk` (136.5 seconds). |
| Backend tests | Pass | Five checks cover authenticator codes, existing-database crop migration, demo mode HTTP integration, crop catalog groups, tokenless crop CRUD, disabled auth endpoints and dashboard inline JavaScript syntax. |
| Backend syntax | Pass | `npm run check` validates server and database JavaScript. |
| Diff whitespace | Pass | `git diff --check`. |
| GitHub Actions run 45 | Pass | Flutter tests/analysis and Android debug APK; Ubuntu backend syntax/integration tests; Windows backend integration tests and packaged app build. [Run details and artifacts](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42371103365). |

During validation, the HTTP smoke test exposed an SQLite CLI output-buffer
overflow when startup loaded trend history for the expanded crop catalog. The
buffer is now 32 MB. The widget test exposed an event-stream retry timer that
survived widget disposal; the timer is now cancellable and disposal is covered
by the passing widget test. Run 44 first exposed a missing SQLite CLI on the
Windows runner. Run 45 provisions it and all three jobs pass.

## Later unverified crop-package edits

The current working tree adds fruit and vegetable profiles, crop groups,
storage notes and an SQLite migration, plus selected-crop guidance in both
clients. These edits were made after the recorded code commit and are not
covered by the checks below. Do not treat this report as verification of the
new package; run the backend migration against both a fresh and existing
database and check crop selection in web and mobile before release.

## Checks run

| Check | Result | Notes |
|---|---|---|
| `flutter test` | Pass | Fresh-install mobile screen assertion passes. |
| `npm test` in `backend/` | Pass | Runs the authenticator-code test. |
| `node --check backend/server.js` and `backend/database.js` | Pass | JavaScript syntax checks. |
| Web inline JavaScript `node --check` | Pass | Inline script extracted from `backend/public/index.html`. |
| Isolated backend login flow (historical) | Pass | Confirmed demo PIN absent from response, demo skip works, credentials save, and email/password sign-in succeeds. This predates demo auth removal. Used a temporary SQLite database. |
| `dart analyze lib` | No errors | 14 style/context informational notices remain. |
| `git diff --check` | Pass | No whitespace errors at the time of the code commit. |
| GitHub Actions Android debug APK build | Pass | Run 42360332399. |
| GitHub Actions Windows backend tests/package | Pass | Run 42360332399. |

GitHub Actions also annotated that its v4 checkout/setup-node/upload-artifact
actions target Node 20 and were being run under Node 24. The workflows still
completed successfully.

## Not exercised

- The web login and credential forms have not been exercised in an interactive
  browser. The backend path was checked through HTTP requests.
- The Android APK and QR pairing have not been exercised on a physical phone.
- The packaged Windows tray controls have not been exercised interactively.
- SMS delivery, physical sensor identity/input, production HTTPS deployment,
  production account recovery, and performance were not tested.

## Coverage boundaries

The committed backend test suite currently covers authenticator code
generation/verification. The widget test checks a fresh mobile install. The
isolated login integration flow is a one-off verification, not a checked-in
automated regression test. These checks do not establish production security,
SMS delivery, device identity, or data isolation for global monitor routes.
