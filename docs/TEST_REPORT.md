# Verification record

**Updated:** 7 November 2026
**Branch:** `exe-work`
**Code commit:** `e2161c6` (`Improve farmer sign-in and center mobile crops tab`)
**Actions:** [run 42360332399](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42360332399)

## Checks run

| Check | Result | Notes |
|---|---|---|
| `flutter test` | Pass | Fresh-install mobile screen assertion passes. |
| `npm test` in `backend/` | Pass | Runs the authenticator-code test. |
| `node --check backend/server.js` and `backend/database.js` | Pass | JavaScript syntax checks. |
| Web inline JavaScript `node --check` | Pass | Inline script extracted from `backend/public/index.html`. |
| Isolated backend login flow | Pass | Confirmed demo PIN absent from response, demo skip works, credentials save, and email/password sign-in succeeds. Used a temporary SQLite database. |
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
