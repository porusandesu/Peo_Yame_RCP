# Handoff — Peo Yame Storage Monitor

Updated: 7 November 2026

## Workspace

- Project: `/home/porusandesu/Documents/storage_monitor_flutter`
- Branch: `exe-work`
- Latest committed revision reviewed: `e64fd93` — `Add Windows backend tray controls and clarify OTP feedback`.
- Consult `git log` for the complete history and `git status` for local edits.

## Current worktree

The committed application includes QR pairing and cross-device account refresh,
farmer crop and sensor assignments, Google Authenticator sign-in, and the
branded Windows launcher. See [changes-2026-11-07.md](changes-2026-11-07.md)
for the recent commit history and current local work.

Commit `e64fd93` adds a Windows notification-area menu with web panel launch,
backend restart and shutdown, and application exit actions. OTP verification
shows incomplete-code feedback and a busy state. An isolated backend OTP
request → verify → authenticated-account check passed. The web UI and tray menu
still need interactive browser/device checks.

Flutter widget/backend tests and JavaScript syntax checks passed. GitHub Actions
run [42356938067](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42356938067)
passed the Android debug APK build and Windows backend tests/package for
`e64fd93`. Earlier run [42355687815](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42355687815)
also passed both jobs for the account-pairing changes. `dart analyze` did not
return diagnostics within 30 seconds. The APK and tray controls have not been
exercised interactively on devices.

Account records, crop locations, sensor assignments, and sessions live in the
backend SQLite database. Web and mobile clients see the same data when they use
the same running backend and sign into the same phone-number account. Separate
backend instances have separate databases. The mobile default URL
`http://10.0.2.2:3000` is for an Android emulator; on a phone, pair from the web
app's **Connect mobile app** window or enter the reachable backend address on
the signed-out screen.

Recent project notes describe Windows backend packaging, mobile QR pairing and
sign-in, farmer accounts and crop sensor assignments, app reconnect handling,
and Peo Yame branding. See [changes-2026-11-06.md](changes-2026-11-06.md) and
[changes-2026-11-07.md](changes-2026-11-07.md).

## Build and verification evidence

- [ANDROID_BUILD_2026-11-06.md](ANDROID_BUILD_2026-11-06.md) records a successful
  root Flutter release APK build (52.8 MB) and SHA-256
  `652dc1899dcfd1ac01e1acdfde5be739fd86d124c92cb6a1ad562e07f5dda980`.
- That build evidence names source `pauls-branch` at `ff9e76f`; it does not
  include the later `exe-work` profile, connection, navigation or chart changes.
- The changes note records successful Windows backend packaging/upload in
  GitHub Actions run [42261817394](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42261817394).
- Earlier formatting and backend/dashboard syntax checks are recorded in the
  change notes. `dart analyze` timed out without returning diagnostics during
  that earlier update.
- The APK was not installed or exercised on a physical phone. SMS delivery,
  physical sensor input, and production account security are not implemented.

## Suggested continuation

1. Exercise signed-out mobile backend pairing, farmer registration and OTP on
   an emulator and physical phone; then verify that profile and crop changes
   appear in both clients while connected to the same backend.
2. Verify the OTP flow in the browser and the tray menu on Windows after the
   current edits pass GitHub Actions.
3. Keep the prototype on a controlled demo network: it uses plain HTTP and
   local demo OTP behavior.

## Project documentation

Start with the root [README](../README.md), then consult
[architecture](ARCHITECTURE.md), [risk register](RISK_REGISTER.md),
[baseline audit](BASELINE_AUDIT.md), and [test report](TEST_REPORT.md).
