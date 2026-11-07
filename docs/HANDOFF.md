# Handoff — Peo Yame Storage Monitor

Updated: 7 November 2026

## Workspace

- Project: `/home/porusandesu/Documents/storage_monitor_flutter`
- Branch: `exe-work`
- Latest committed revision reviewed: `8acfe79` — `Launch branded Windows app without console window`.
- Consult `git log` for the complete history and `git status` for local edits.

## Current worktree

The committed application includes QR pairing and cross-device account refresh,
farmer crop and sensor assignments, Google Authenticator sign-in, and the
branded Windows launcher. See [changes-2026-11-07.md](changes-2026-11-07.md)
for the recent commit history and current local work.

The worktree currently has uncommitted changes in `backend/public/index.html`,
`lib/main.dart`, and `test/widget_test.dart`: the web OTP prompt now updates a
dedicated text element; mobile PIN resend retains the name for a pending farmer
registration; signed-out mobile users can enter or scan the web backend address
before creating/signing into an account; changing the backend while signed in
clears the previously saved token and returns to sign-in. The widget test now
checks the fresh-install sign-in screen. These changes were formatted.
The Flutter widget test and backend authenticator test pass, as do JavaScript
syntax checks and `git diff --check`. `dart analyze` did not return diagnostics
within 30 seconds. GitHub Actions run [42355687815](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42355687815)
passed both the Android debug APK build and Windows backend tests/package for
commit `bc5d5c1`. The APK has not been exercised on a physical device.

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
2. Run relevant Flutter and backend checks before committing the local edits.
3. Keep the prototype on a controlled demo network: it uses plain HTTP and
   local demo OTP behavior.

## Project documentation

Start with the root [README](../README.md), then consult
[architecture](ARCHITECTURE.md), [risk register](RISK_REGISTER.md),
[baseline audit](BASELINE_AUDIT.md), and [test report](TEST_REPORT.md).
