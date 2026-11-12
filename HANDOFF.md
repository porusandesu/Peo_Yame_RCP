# Peo Yame — build handoff and resume plan

## Latest status — 2026-11-12 (session security and demo sync verified)

The source audit fixes are pushed to `exe-work`; GitHub Actions v102
(`43197194366`) verified session idle expiry and v103
(`43199378655`, https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43199378655)
passed backend, Android, and Windows jobs for account+IP lockout and shared
Guided Demo live sync. v104
(`43200357299`, https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43200357299)
verified the two-hour lifetime for QR-created Guided Demo sessions across
backend, Android, and Windows. v107
(`43203834344`, https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43203834344)
verified that changing authenticator state revokes other sessions while
retaining the current session. No local application builds or tests were run.

The audit tightened browser origin and CSRF checks, added cookie-based web
session restoration/idle expiry, required password re-authentication for
authenticator setup, expired approved QR pairings at their deadline, and
enabled the Windows LAN listener for phone pairing. v99 exposed a regression
for cookie-bearing clients logging in after restart; v100 covers and fixes it.
No seeded test account exists; use Instant Demo or register an account.

Open security and verification gaps remain: the dashboard CSP is disabled for
its inline scripts/handlers. A scoped activity feed is now in Settings, but
its source changes are pending CI and it does not yet include failed
sign-ins/lockouts. Authenticator changes revoke other sessions; the current
session's TOTP verification state remains tied to sign-in and is cleared when
the authenticator is disabled. Windows Firewall, real-device LAN access, and
manual visual/accessibility checks are not verified. See
`docs/TEST_REPORT.md` and `docs/FEATURE_PARITY.md`. Older continuation notes
below are historical and superseded by this status.

## Correction to the Windows launch history — 2026-11-11

The user reports that the v83 Windows app did not launch its backend in actual Windows use. The earlier v83 “passed startup” wording was wrong for the user's reported outcome: v83 CI passed only the special --self-test path and did not launch the normal tray app. v84 also tested a dashboard URL marker from that self-test rather than normal app startup; v85 reused that insufficient check. Do not treat v83–v85 as proof the normal Windows app works. The new workflow must start the unmodified single executable normally from a clean folder on Windows and verify its live backend and dashboard.

The Android APK was using Flutter-generated launcher icons; its brand PNG only appeared in app content. The Windows executable embedded a tray icon but did not set its executable icon. Current source now installs the supplied Android density/adaptive launcher assets and sets the supplied Windows ICO as both executable and tray icon. Verify those assets in the next CI build.

Source baseline is commit 9519a2d (v87 export changes) in /home/porusandesu/Documents/Peo_Yame_Rebuilt; this pending change adds the rebuilt Windows launch check and corrected app icons. Runs v85–v87 used the old Actions concurrency group; v85's Android artifact upload was still active and v86/v87 were queued. The replacement workflow uses a different group. It launches the normal executable, checks health/dashboard/account registration, then separately checks restart/reset/stop. Android CI checks branded launcher resources in the APK. No local app builds or tests.

## Current state: ACTIVE — user resumed on 2026-11-11; latest update 2026-11-11

The user reports the Windows app still does not launch and has explicitly
directed that the backend and web dashboard be consolidated into one executable
that starts everything without setup or prompts. The v82 Windows publish failed because MSBuild resolved embedded resource paths relative to the windows project. The user reports that the v83 Windows app did not launch its backend in normal use. v83-v85 CI checks used the special self-test path, not normal tray startup, so those checks were insufficient. A replacement Windows workflow now tests normal launch from a clean folder. v81 only verifies the preceding ZIP build.

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
4. Continue verifying the inspection reminders and check Android artifacts.
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

## Current continuation status (2026-11-11)

The current rebuild is in `/home/porusandesu/Documents/Peo_Yame_Rebuilt`, detached at commit `ec615cf` (v86 sensor-management source). Run `43094194736` passed backend tests, Windows single-executable publish/lifecycle checks, Android analysis/tests, and Android release build; Android artifact upload was in progress at the last poll. Do not run local app builds or tests.

Sensor management adds account-owned records, manual ID registration, location link/unlink, reading ingestion, simulated `PY-DEMO-1` readings, and ownership checks. Physical pairing/discovery is not implemented. Run `43095622399` (v86, commit `ec615cf`) was queued while the v85 Android artifact upload remained in progress; no v86 result is verified yet. v87 source work adds CSV/Markdown reading export, web file downloads, Android clipboard export, and API format checks. Continue using `git diff --check`, CI only for app builds/tests, and update the evidence after those runs. The user has asked to continue building without waiting for manual testing.

## Session update 2026-11-11 (later) — workspace and parity progress

- Workspace moved to `C:\Users\PaulM\Documents\Default Project\Peo_Yame_RCP` on Windows (git identity repo-local `porusandesu`); `gh` CLI is at `C:\Program Files\GitHub CLI\gh.exe` (not on PATH) with `repo`+`workflow` scopes.
- The v2 parity prompt (11 Nov 2026) and the 20 supplied design CSS files are archived at `docs/design-reference/` and are the source of truth alongside this handoff.
- A 34-row defect audit against parity prompt section 11 found 26 rows already fixed; confirmed gaps: manual QR code entry, TOTP, web demo-tool gating, chart axis labels/last-sync unification, 30-item catalog, SSE live events, biometric app lock, pairing password re-check, export `estimate_note`, Windows installer.
- Batch 1 committed and pushed as `2a226f8`: `estimate_note` in CSV/Markdown exports (+tests), web Demo tools gated on `guidedDemoEnabled && mode!=="farmer"`, unified `HH:mm:ss` last-sync from backend in web+mobile, "Add storage location" label. v89/v90 Windows and backend jobs green with these changes.
- v89/v90 Android remains red: the release APK contains zero mipmap/launcher entries (`APK icon entries: []`) even though the pre-build checks confirm `mipmap-xxxhdpi/ic_launcher.png` and `mipmap-anydpi-v26/ic_launcher.xml` exist on disk and the manifest references `@mipmap/ic_launcher`. Forensic diagnostics (APK size, total entries, res sample, `aapt2 dump badging` icon lines) added for the next run.
- Batch 2 (in the next commit): backend short codes — `pairings.short_code_hash` column + migration + index, Crockford `normalizeShort`, `pairingBy` resolves by short code or full code, `pairingCreate` returns 8-char `shortCode`, both QR create endpoints return it, web shows "Can't scan? type: XXXX-XXXX" hints; mobile — JSON-or-short-code parse fallback, shared `cameraRationale()` helper, dedicated `scanWebQr()` wired to Settings "Log in on computer" (previously it wrongly called `scanPhoneQr`, leaving `approveWeb` dead code); tests exercise short-code resolution in both flows.
- Remaining queue after batch 2 CI: TOTP → SSE live events + offline recovery → 30-item catalog → biometric app lock → pairing password re-check → DB encryption-at-rest → Windows installer.

## Session update 2026-11-12 — audit batch, TOTP, v92–v94 CI

- Full audit of web/mobile/backend completed. Fixes pushed in `27c1d4b` (TOTP + hardening + web/mobile data-layer repairs), `7f2fa6f` (v92 root causes: test missing `content-type: application/json` on `/authenticator/enable`; stray brace closed `_HomeState` early), and `4ff22b6` (owner-session binding relaxed for TOTP-verified sessions — root cause of v93 backend `404 !== 200` at `server.test.js:31`; also records v92/v93 TEST_REPORT evidence).
- v93 (run `43159003399`): Windows green (5th consecutive), **Android green for the first time since v88** — the aapt2 badging/resources-based icon assertion works and `application: label='Peo Yame'` is verified. Backend failed only on the TOTP approval session binding; fix is in `4ff22b6`, v94 pending.
- **v94 (run `43160038257`) is the first fully green run**: backend (full TOTP block + prototype-key guards), Windows (6th consecutive), and Android all pass. TOTP is CI-proven; see TEST_REPORT for exact assertions.
- Windows CI contract held: `PEO_YAME_DATA_DIR`, `PEO_YAME_SELF_TEST_LOG`, `PEO_YAME_NO_BROWSER=true`, `PORT`; restart resets instance data and preserves login details (intentional, per parity prompt).
- Known issue reported, not changed: `windows/Program.cs` always sets `PEO_YAME_DEMO_ENABLED=true`, contradicting parity prompt §8.2 (demo button should be absent in a normal install). Awaiting user decision.
- Audit false positives verified directly (no change needed): `removeSite`/`signout` are already `async`; SQL placeholder counts correct; no cross-user leaks in `/status`, `/trends`, `/export`, `/alerts`; claim/scan CAS and redeem double-spend guards correct; prepared statements throughout.
- Next after a green v94: SSE real events + offline recovery → 30-item catalog → biometric app lock → pairing password re-check → DB encryption-at-rest → Windows installer.

## Current status — v97 feature-parity CI green

The active implementation worktree is `/tmp/peo-yame-feature-parity`, branch
`copilot/feature-parity`, based on `f0ddde4`. The original Documents workspace
and the divergent `storage_monitor_flutter` checkout were not modified. Commit
`2c1bac6` is pushed to `exe-work`.

Source changes now cover server-sent mutation events with session validity
checks; web and Android reconnect/offline behavior; a 30-item Botswana-oriented
crop catalog, per-user custom entries, and persisted crop selection; Android
biometric app lock; password and enabled-TOTP re-check for phone pairing
creation; encrypted SQLite with plaintext migration and encrypted-copy
recovery; and a per-user Windows installer. Windows bundle assembly now copies
all backend source modules, not just `server.js`. Normal launcher configuration
defaults Guided Demo off unless explicitly enabled. `docs/CROP_CATALOG.md`
states the available Botswana survey basis and its limitation: the cited
official sources do not publish a ranked top-ten list across all three
categories.

GitHub Actions v97 (`43173464542`) passed backend tests, Android widget
tests/analyzer/release APK and launcher verification, and Windows normal
launch, restart/reset, installer install/launch, encrypted-storage acceptance,
and uninstall. Artifacts `Peo Yame v97 Android` (71,096,129 bytes) and
`Peo Yame v97 Windows` (311,259,951 bytes) were uploaded. No local app
builds/tests were run. The earlier v96 installer file-locking issue is fixed
and superseded by v97's green acceptance run.

The automated feature-parity batch is complete. Manual visual/accessibility
and real-device checks remain open. The catalog is evidence-informed and
Botswana-oriented, not a statistically ranked top ten; crop-band and estimate
baselines still need domain validation. The Windows launcher defaults Guided
Demo off unless explicitly enabled.
