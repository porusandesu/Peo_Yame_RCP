# Handoff — Peo Yame Storage Monitor

Updated: 7 November 2026

**Current worktree auth change:** Demo authentication has been removed. Web and
mobile now show a **Demo mode** button that opens the shared profile for
**Mr Lesego Lefoko** (`LLefoko@email.co.bw`) without login. Demo auth routes
remain disabled; production auth remains available. The current UI/profile
change is awaiting GitHub Actions validation.

## Workspace

- Project: `/home/porusandesu/Documents/storage_monitor_flutter`
- Branch: `exe-work`
- Latest pushed code: `2e18721` on `exe-work`; CI run 46 passed. See `git log --oneline` for the full history.
- Consult `git log` for the complete history and `git status` for local edits.

## Current worktree

The current worktree adds a Botswana crop starter package for grains, pulses,
oilseeds, vegetables and fruits. The backend seeds profile groups, room
temperature/RH ranges, notes and dry-grain moisture targets into SQLite; both
clients display selected-crop guidance. Existing databases receive a startup
migration. See [BOTSWANA_CROP_STORAGE_PACKAGE.md](BOTSWANA_CROP_STORAGE_PACKAGE.md)
for the package sources and limits.

The web crop selector groups entries by type, and the mobile selector labels
each crop with its type. A suggested low-literacy farmer workflow is documented
as future usability work; it has not been field tested or fully implemented.
The checked-in backend integration test now covers demo login removal, crop
catalog groups and demo crop create/list/delete through the API.

The latest change adds an explicit demo entry button to both sign-in screens.
Demo mode presents only the demo profile and button; tapping it loads the shared
backend profile. Production login still validates the backend demo flag before
allowing entry to demo mode. The backend profile is updated to the requested
name/email. GitHub Actions run [42374133023](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42374133023)
passed the mobile widget test, web/API checks, Android build and Windows package.
The APK and Windows ZIP are available as artifacts from the run page.

Commit `6dff368` adds phone-to-web QR sign-in approval through the backend; the
crop and demo-auth work described here is newer than that commit.

The committed application includes QR pairing and cross-device account refresh,
farmer crop and sensor assignments, Google Authenticator sign-in, and the
branded Windows launcher. See [changes-2026-11-07.md](changes-2026-11-07.md)
for the recent commit history and current local work.

Code commit `e2161c6` centers **My Crops** in the five-tab mobile
navigation, makes refresh compact, and tolerates two missed 20-second backend
polls before showing offline. In production, the signed-out mobile page offers
phone verification for an existing farmer account or one-use QR pairing issued
by an authenticated web account. Phone sign-in supports PIN or Google
Authenticator verification. New farmer accounts are created on the web.

The same code commit adds web email/password sign-in and password setup after
phone verification for accounts without credentials. Passwords use Node's scrypt with random
salts; the demo PIN is no longer returned to the browser. The login page's
**Sign in with QR code** section explains mobile pairing; the actual QR remains
behind the signed-in web session. Email is part of farmer account records and
is migrated for existing databases. See the latest section in
[changes-2026-11-07.md](changes-2026-11-07.md) for validation status.

The account-security skip described in earlier change notes is no longer part
of the demo flow. Demo mode does not create or restore authenticated sessions.

Recent local checks passed the Flutter widget test, all five backend tests,
backend and web inline-script syntax checks, `git diff --check`, and a debug APK
build. `flutter analyze --no-pub --no-fatal-infos lib` passes with 22 existing
style/context informational notices. GitHub
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

- Current local validation: `flutter test --no-pub` passed the demo-home widget
  test; `backend/npm test` passed five checks including demo API auth/crop
  integration; `flutter analyze --no-pub --no-fatal-infos lib` completed with
  informational lints; `flutter build apk --debug --no-pub` produced
  `build/app/outputs/flutter-apk/app-debug.apk` in 136.5 seconds.
- The demo integration test exposed an SQLite output-buffer crash on startup
  after seeding the expanded catalog. The CLI output limit is now 32 MB and the
  integration test passes. The widget test exposed an uncancellable event-stream
  retry timer; the reconnect timer is now cancelled on controller disposal.
- The expanded GitHub Actions workflow adds Flutter widget tests and analysis,
  backend syntax/integration checks, Android APK build/artifact upload, and
  Windows backend tests/package. Run [42371103365](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42371103365)
  passed all three jobs: Flutter tests/analysis and Android debug APK, Ubuntu
  backend syntax/integration tests, and Windows backend tests plus packaging.
  Windows CI now installs the pinned SQLite CLI before integration tests.
- Run 45 uploaded the Android debug APK and Windows backend ZIP as Actions
  artifacts. They are available from the run page for 14 and 30 days,
  respectively. The local APK is at
  `build/app/outputs/flutter-apk/app-debug.apk`.
- Run 46 validates the latest demo entry and profile change on GitHub-hosted
  Ubuntu and Windows runners. The local machine was not used for this change's
  tests or build.

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

1. Exercise production phone/email and bidirectional QR SSO on an Android
   emulator and browser; demo mode intentionally bypasses those screens.
2. Verify the crop package on a real existing database and evaluate the
   low-literacy workflow with Botswana farmers before claiming usability.
3. Keep the prototype on a controlled local network. Plain HTTP and unscoped
   global monitor APIs are not intended for exposure.

## Project documentation

Start with the root [README](../README.md), then consult
[architecture](ARCHITECTURE.md), [risk register](RISK_REGISTER.md),
[baseline audit](BASELINE_AUDIT.md), and [test report](TEST_REPORT.md).
