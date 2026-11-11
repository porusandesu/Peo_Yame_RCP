# Peo Yame — build handoff and resume plan

## Current state: ACTIVE — user resumed on 2026-11-11; latest update 2026-11-11

The user reports the Windows app still does not launch and has explicitly
directed that the backend and web dashboard be consolidated into one executable
that starts everything without setup or prompts. Commit `a7e8e41` implements
embedding Node, SQLite dependencies, backend, dashboard and icon in a
self-contained executable; silent extraction into LocalAppData; free loopback
port selection; backend start; and automatic browser launch. v82 Windows CI
failed at publish because MSBuild resolved the resource paths relative to the
`windows/` project directory. v83 passed the standalone executable publish and
isolated startup/health/dashboard checks and produced `Peo Yame v83 Windows`
(107,262,737 bytes). Android release is still running. A follow-up adds a CI
assertion that the standalone executable requests opening the browser URL; that
check is not yet pushed or verified. Do not ask the user to try a build until
the follow-up Windows check passes. v81 only verifies the preceding ZIP build.

Active session management has now passed CI v81 (backend, Android analysis,
widget test and APK; Windows package still used prior ZIP layout). v80 failed
because of a test count assumption and a Dart syntax error; both were fixed in
`a30686b`. See `docs/TEST_REPORT.md` for exact runs. The current Documents
workspace is `/home/porusandesu/Documents/Peo_Yame_Rebuilt`; keep the old
`storage_monitor_flutter` workspace untouched because it diverges and contains
user assets. Do not run local application builds or tests. Use GitHub Actions.

The source-of-truth implementation brief is
`/home/porusandesu/Downloads/PEO_YAME_CODEX_MASTER_BUILD_PROMPT.md`, together
with the supplied visual CSS and SVG references. Figma was not accessible in
the earlier audit. Preserve the clean rebuilt architecture and supplied logo.

### Immediate continuation

1. Finish and inspect the standalone Windows embedding workflow and launcher.
2. Push and wait for the isolated executable startup check and full CI.
3. If CI fails, read the complete failing job log, correct the cause, and rerun.
4. Only after the artifact is verified, send the user the direct `.exe` artifact
   and ask them to try it. Do not send another ZIP as the requested solution.
5. Continue the remaining parity items from `docs/FEATURE_PARITY.md` and the
   master prompt, preserving the no-local-build/test constraint.

Earlier investigation notes below are historical unless superseded above.

The user resumed the build and directed Codex to follow the supplied CSS files
and SVG designs. The previous pause is lifted. Continue on the current scratch
rebuild only; do not reuse the retired application code. Do not run local app
builds or tests. Use GitHub Actions and keep this handoff current.

## Conversation context and binding instructions

The user asked to build both the Android and Windows applications in one effort, closely following three supplied SVG designs and the workflow in the parity QR prompt. They explicitly said not to use any old application code from previous versions, branches, or local app files. The rebuild was authored as new source after cleaning the `exe-work` branch. Keep the existing supplied logo assets (PNG now in the repository at `assets/peo-yame-512.png` and copies for web/mobile).

Source-of-truth inputs named by the user:
- `/home/porusandesu/Downloads/peo-yame-parity-qr-prompt.md` — requirements to follow; user said to ignore other MD requirement files.
- `/home/porusandesu/Downloads/peo-yame-design.svg`
- `/home/porusandesu/Downloads/peo-yame-design-2.svg`
- `/home/porusandesu/Downloads/peo-yame-design-3.svg`
- Logo directory: `/home/porusandesu/Documents/storage_monitor_flutter/Peo_Yame_logo_assets`.

The local machine must not be used to run application code, builds, or tests. Use GitHub Actions for iteration and verification. Target repository is `porusandesu/Peo_Yame_RCP`, branch `exe-work`. GitHub MCP was connected and authenticated as `porusandesu`; push permission was observed earlier. A previous successful baseline at v73 built Android and Windows artifacts, but the QR implementation added later is unverified and the latest run failed. Do not treat v73 as proof of current source quality.

Earlier build requirements:
- Remove old Actions workflows and replace them with one workflow that tests backend, Android and Windows tray lifecycle, creates Android APK and Windows app artifacts.
- One Windows installer should install/configure the app and embedded backend, then run it after installation. Preserve login details on backend restart while resetting instance data as specified in the parity prompt.
- Windows notification-area actions: Start (launch backend then webapp), Restart backend (reset instance while preserving login details), Stop server, Quit app.
- Android APK and Windows app use the “Peo Yame vN” naming convention; increment from the prior run/build number.
- User asked for all features to be tested through GitHub Actions.

New requirements just added by the user:
1. After achieving the initial scope in `peo-yame-parity-qr-prompt.md), add a built-in catalog containing the 10 most popular fruits, 10 vegetables, and 10 crops that the app tracks at minimum (30 seeded items total). Let each user add their own items. Determine and document the popularity basis/region, and verify catalog visibility, selection/use, custom additions, persistence and account isolation.
2. Secure and encrypt every database. Before implementation, inspect the current storage architecture and choose a maintained encryption approach compatible with backend packaging and Windows installer. Protect database keys/secrets, migration and backup behavior, and test encryption-at-rest, access control, restart, migration and recovery through CI. Do not call a database “encrypted” until tests verify stored files do not expose plaintext and key handling is documented.
3. The backend must ultimately be integrated into a Windows installer so installation sets up and launches the complete app.

## Latest GitHub Actions evidence

Run `43081552333` (Peo Yame v77), commit
`c1f01a3e737a12aebc3a880eccced887c17cabe4`, passed backend tests, Android widget
test/analyzer/release APK, and Windows packaged backend lifecycle checks. Both
Android and Windows ZIP artifacts were uploaded. This verifies the compile
blocker fix, not the pending visual changes or the full product scope.

Run `43086745905` (v78), commit `7a29c8368d1979e0bd4a2d84f1082d77f6e39117`,
failed: the web static test asserted a mobile welcome heading on the web sign-in
gate, and Android compilation found an integer `Container.padding`. Both are
fixed in the next commit; v79 is pending.

Latest run: `43057685000`, commit `ed281252abed97c99977194f681bf00c6cd8821d`, branch `exe-work`. All three jobs failed:
- Backend job `130651439714`: `backend/src/server.js:53` throws `SyntaxError: Invalid regular expression flags`. CI displayed a malformed escaped regex in `lanBase` (including the public URL trailing slash regex and private IPv4 patterns). This prevents server startup and causes the API test failure “backend did not start”.
- Android job `130651439605`: Dart compile errors in `mobile/lib/main.dart`: line 22 malformed `catch`; line 61 “Not a constant expression”; `LocalAuthentication.authenticate` has no named parameter `options` for the selected dependency version. Android release build was skipped.
- Windows job `130651439129`: failed at “Install backend dependencies and test”, because it runs the same backend test. Publish/package/artifact steps were skipped. No current Windows installer has been produced.
- Therefore latest run has no Android or Windows artifacts and all target features remain unverified at this revision.

Earlier run v73 `43053668232` passed its jobs and produced v73 Android and Windows artifacts before the QR changes. v74 `43057172442` failed on duplicate YAML keys for `mobile_scanner` and a backend test startup timeout. v75 is the latest failing run; use it as the current baseline for future diagnosis.

## Source/status notes

The current `exe-work` branch is a scratch rebuild; do not copy code from prior app versions or another branch. A same-session scratch snapshot was stored in Codex memory as `peoyame:scratch-files` (files include backend, web, Flutter, Windows tray app, workflow and docs), but future work should first inspect the current GitHub branch and its commit rather than assume that ephemeral memory exists. The failed v75 source should be treated as an unfinished starting point for debugging, not a completed product. Preserve the user’s instruction against reuse of old app code.

The implementation currently has a fresh Express/SQLite backend, web UI, Flutter app with QR flows in progress, and WinForms tray app. QR endpoints/clients were introduced, but end-to-end QR flows have not passed CI. Current known scope gaps from the implementation notes include: full QR manual-code fallback/expiry refresh/rate limits/session handling; TOTP; active-session/device management and revoke; secure cookie/session flow; sensor integration; exports; cross-client live events and offline behavior; crop-inspection reminders; complete demo tools/run sheet; LAN phone-to-PC reachability; Windows installer; encrypted databases; and the new 30-item catalog with user-defined items. Reconcile these against the parity prompt before coding; this list is a working gap inventory, not a substitute for the prompt.

## Resume sequence for the next Codex instance

1. Read this handoff and the exact `peo-yame-parity-qr-prompt.md` plus all three SVGs and supplied logo. The parity prompt remains the only functional source of truth; designs are visual references. Confirm the GitHub MCP connection/auth and inspect the current `exe-work` head and workflow status.
2. Keep the user’s no-local-execution constraint. Do not run app code, builds, or tests locally. Do source review/editing only, then rely on GitHub Actions.
3. Diagnose and fix the three confirmed v75 compilation blockers (backend regex, Dart catch syntax, constant expression, local_auth method signature). Review all backend and Dart source for adjacent syntax/API issues. Do not merely rerun without a code correction.
4. Audit parity prompt feature-by-feature, compare each SVG screen to web/mobile implementation, and make a concise checklist of remaining requirements in the repo. Preserve the supplied logo.
5. Implement the entire initial parity/QR scope, Windows lifecycle and packaging, and automated functional checks. Ensure the tray actions behave as specified and that restart resets volatile instance data while retaining login credentials. Ensure Windows installer embeds/configures the backend and web assets and launches on install/startup as required.
6. Run CI on `exe-work`; inspect each failing job’s complete relevant logs and iterate. Validate actual backend APIs/QR approval flow, Flutter analyze/widget/integration behavior, Windows tray lifecycle, installer install/launch/uninstall behavior, artifact naming/version increments, and Android APK creation. Do not claim targets from compile-only tests.
7. Only after the initial parity/QR target succeeds, implement the user’s 30-item fruit/vegetable/crop starter catalog plus user-defined additions; choose a defensible and documented popularity basis. Add functional tests for seed data, selection, custom items, persistence, ownership/isolation, and UI.
8. Secure all databases using an audited maintained encryption-at-rest solution suitable for packaged Windows and Android. Design and test secure key provisioning/storage, migrations, restart, backup/restore, and recovery. Use CI tests demonstrating ciphertext at rest and database usability only with the correct key. Verify no secrets are committed or included in logs/artifacts.
9. Keep `docs/TEST_REPORT.md` strictly factual and update the handoff with each new Actions run, failure/root cause, successful test evidence and remaining gaps. Increment artifact version consistently as “Peo Yame vN” for both Windows and Android.
10. Completion means required features are implemented and functionally tested in GitHub Actions, Android APK and Windows installer/app artifacts are successfully produced, and latest `exe-work` Actions run is green. Report artifact links and precise test coverage. Ask the user for any genuinely missing product decision only after independent work that does not depend on it is complete.

## Do not

- Do not start implementation while the user has explicitly paused.
- Do not build/run/test application code on the local machine.
- Do not reuse code from old branches or old app versions.
- Do not state that QR, tray actions, installer, encryption, crop catalog, or other feature is complete without functional evidence from CI.
