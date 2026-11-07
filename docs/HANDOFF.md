# Handoff — Peo Yame Storage Monitor

Updated: 7 November 2026

## Workspace

- Project: `/home/porusandesu/Documents/storage_monitor_flutter`
- Branch: `exe-work`
- Latest reviewed code: current `exe-work` HEAD; see `git log --oneline` for its hash and documentation follow-ups.
- Consult `git log` for the complete history and `git status` for local edits.

## Current worktree

The committed application includes QR pairing and cross-device account refresh,
farmer crop and sensor assignments, Google Authenticator sign-in, and the
branded Windows launcher. See [changes-2026-11-07.md](changes-2026-11-07.md)
for the recent commit history and current local work.

Code commit `e2161c6` centers **My Crops** in the five-tab mobile
navigation, makes refresh compact, and tolerates two missed 20-second backend
polls before showing offline. The signed-out mobile page offers two sign-in
routes: phone verification for an existing farmer account, or one-use QR
pairing issued by an authenticated web account. Phone sign-in supports PIN or
Google Authenticator verification; demo mode offers a bypass because no SMS
is sent. New farmer accounts are created on the web.

The same code commit adds web email/password sign-in, password setup after phone
verification for accounts without credentials, and a demo-only skip for phone
verification and credential setup. Passwords use Node's scrypt with random
salts; the demo PIN is no longer returned to the browser. The login page's
**Sign in with QR code** section explains mobile pairing; the actual QR remains
behind the signed-in web session. Email is part of farmer account records and
is migrated for existing databases. See the latest section in
[changes-2026-11-07.md](changes-2026-11-07.md) for validation status.

The account-security skip now confirms demo mode through an authenticated
backend route and persists the choice in SQLite, so repeat demo phone sign-ins
do not reopen credential setup. The production flow ignores this demo-only
choice. This change is included in the current commit; CI and browser
interaction validation are pending.

Local checks passed the Flutter widget test, backend authenticator test,
JavaScript syntax checks (including the web page's inline script), and an
isolated backend flow covering demo skip, credential setup and password login.
`dart analyze lib` reports no errors and 14 style/context lint infos. GitHub
Actions run [42360332399](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42360332399)
passed both Android APK build and Windows backend tests/package. GitHub noted
that the workflow's v4 actions currently run under Node 24 despite targeting
Node 20. The login flow has not been exercised in an interactive browser.

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
the same running backend. Separate backend instances have separate databases.
For physical phones, create the QR in **Connect mobile app** after signing into
the web app. The Android emulator default URL is `http://10.0.2.2:3000`.

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

1. Exercise the complete browser login, demo skip, credential setup, and
   email/password flows in an interactive browser.
2. Exercise phone-number sign-in and QR pairing on an Android emulator and
   physical phone; verify that profile and crop assignments sync between
   clients on the same backend.
3. Exercise the packaged Windows tray menu interactively.
4. Keep the prototype on a controlled local network. Plain HTTP and unscoped
   global monitor APIs are not intended for exposure.

## Project documentation

Start with the root [README](../README.md), then consult
[architecture](ARCHITECTURE.md), [risk register](RISK_REGISTER.md),
[baseline audit](BASELINE_AUDIT.md), and [test report](TEST_REPORT.md).
