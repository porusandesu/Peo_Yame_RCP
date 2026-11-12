# Test report

## GitHub Actions v104 — demo QR lifetime passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43200357299
Commit: `d3488d6` (Cap demo QR sessions at demo lifetime).

- Backend API tests passed, including the two-hour absolute lifetime for
  QR-created Guided Demo sessions and the 30-minute idle timeout.
- Android tests, analysis, release APK, and packaged launcher verification
  passed.
- Windows normal launch, restart/reset lifecycle, installer, encrypted
  storage, and uninstall checks passed.
- No local application builds or tests were run.

## GitHub Actions v103 — account/IP lockout and demo sync passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43199378655
Commit: `fa6cf58` (Add live sync to Guided Demo).

- Backend API tests passed for five-failure phone+IP lockout, account
  isolation, QR-shared demo sessions, live synthetic readings, and delivery
  to a second session.
- Android tests, analysis, release APK, and packaged launcher verification
  passed.
- Windows normal launch, restart/reset lifecycle, installer, encrypted
  storage, and uninstall checks passed.
- No local application builds or tests were run.

## GitHub Actions v102 — session idle expiry passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43197194366
Commit: `6aaf89e` (Apply idle expiry to all sessions).

- Backend API tests passed, including 30-minute idle expiry for password and
  phone QR sessions.
- Android analysis, tests, release APK, and packaged launcher verification
  passed.
- Windows normal launch, restart/reset lifecycle, installer, encrypted
  storage, and uninstall checks passed.
- No local application builds or tests were run.

## GitHub Actions v100 — security audit fixes passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43179338332
Commit: `0446d6a` (Allow cookie-bearing clients to sign in).

- Backend API tests passed, including CORS/CSRF, cookie-session idle expiry,
  authenticator setup re-authentication, QR expiry, and LAN listener coverage.
- Android tests, analysis, release APK build, and packaged launcher verification
  passed.
- Windows normal launch, restart/reset lifecycle, installer acceptance,
  encrypted-storage verification, and uninstall passed. Android and Windows
  artifacts were uploaded.
- No local application builds or tests were run.

## GitHub Actions v99 — backend and Android passed; Windows exposed a login regression

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43178495585
Commit: `5756018` (Harden browser sessions and QR pairing).

- Backend API tests and Android tests/analysis/release APK passed.
- Windows normal launch passed, but restart/reset lifecycle failed because the
  self-test's cookie-bearing login request was rejected by CSRF validation.
  Login and registration now bypass only the cookie CSRF-token check; CORS
  origin validation remains enforced. Regression coverage and the complete
  Windows lifecycle passed in v100.
- No local application builds or tests were run.

## GitHub Actions v97 — backend, Android, and Windows installer passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43173464542
Commit: `2c1bac6` (Fix installer encrypted database check).

- Backend API tests passed.
- Android widget tests, analysis, release APK build, and packaged launcher verification passed. Artifact `Peo Yame v97 Android` was uploaded (71,096,129 bytes).
- Windows normal launch, backend restart/reset lifecycle, installer build, install/launch, encrypted-database verification, and uninstall all passed. Artifact `Peo Yame v97 Windows` was uploaded (311,259,951 bytes).
- This is the first fully green run for the feature-parity batch, including acceptance of the Windows installer and encrypted storage.
- No local app builds or tests were run. Manual visual/accessibility verification remains open.

## GitHub Actions v96 — backend and Android passed; Windows installer check needs correction

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43171837358
Commit: `23d7c263567c3f26ecb076589349b58c3b8b25e1`.

- Backend API tests passed, including new coverage for all 30 catalog entries, custom-crop account isolation and restart persistence, SSE selection events, password/TOTP pairing re-checks, and database encryption, plaintext migration, wrong-key rejection, reopen, and encrypted-copy recovery.
- Android widget tests, analysis, release APK build, and packaged launcher verification passed.
- Windows single-executable normal launch and restart/reset lifecycle checks passed; the installer compiled successfully. The final installer check installed and launched the app, then failed when `File.ReadAllBytes` tried reading the database while the running SQLite process held it open. The workflow now performs the ciphertext header check after stopping the app. No Windows artifacts were uploaded for v96 because the final installer check failed.
- No local app builds or tests were run. The only local validation was `git diff --check`.

## Feature-parity implementation batch — CI complete; manual verification remains

The current source worktree is based on `f0ddde4` and contains changes for SSE
events and client reconnects, custom crop catalogs, biometric app lock, phone
pairing re-authentication, encrypted SQLite storage, and a Windows installer.
The v97 evidence above confirms the backend tests, Android build and tests, and
Windows installer acceptance. Manual visual/accessibility verification remains
open.

## GitHub Actions v94 — first fully green run: backend, Windows (6th consecutive), and Android all pass

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43160038257
Commit: `4ff22b6` (Allow TOTP-verified sessions of the pairing owner to manage phone pairings).

- Backend API tests: passed. This includes the full TOTP block — setup/enable (correct code → 200, wrong code → 401), login requiring a code, owner-status/approve with the TOTP re-authenticated session, sessions `totpVerified`, disable with wrong password → 401 and correct password → 200, and the prototype-key crop guards (`/status?crop=constructor` → 400, `/sites` POST with `crop:"constructor"` → 400). TOTP is now CI-proven end to end.
- Windows: normal-launch check and restart/reset lifecycle both passed; artifact uploaded. Sixth consecutive green Windows run.
- Android: analysis, widget tests, release APK build, and the aapt2 packaged-icon/label assertion all passed.
- This is the first run since the rebuild began where all three jobs are green together. Backend TOTP status in FEATURE_PARITY.md upgraded from "not yet CI-proven" to CI-proven at this run.
- No local app builds or tests were run.

## GitHub Actions v93 — Windows green (5th consecutive); Android green for the first time since v88; backend failed on TOTP approval session binding (fix applied)

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43159003399
Commit: `7f2fa6f` (Fix v92 CI: authenticator test missing JSON content-type; stray brace closed _HomeState early).

- Windows: normal-launch check and restart/reset lifecycle both passed; artifact uploaded. Fifth consecutive green Windows run.
- Android: analysis, widget tests, release APK build, and the aapt2-based packaged-icon assertion all passed — first green Android run since v88. The aapt2 badging/resources-based assertion correctly verifies the launcher icon despite the toolchain's resource path shortening, and the manifest label fix is in.
- Backend API tests: failed with `404 !== 200` at `server.test.js:31` — the phone-pairing approve call made with the TOTP re-authenticated session. The server bound approval to the exact `owner_session_hash` of the session that created the pairing code, so once TOTP was enabled, a re-authenticated session (a different session of the same user) could never approve, which also dead-ends the real UX. Fix applied locally: owner-status/approve/deny now accept any session of the pairing owner when that session has passed TOTP verification (`req.user.totp_verified`); the owner-user check remains strict. Server parse-verified in Chromium after the change.
- No local app builds or tests were run.

## GitHub Actions v92 — Windows green (4th consecutive); two new bugs in the pushed batch found and fixed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43158218655
Commit: `27c1d4b` (TOTP authenticator; fix web/mobile data layers, pairing state races, hardening).

- Windows: normal-launch check and restart/reset lifecycle both passed; artifact uploaded. Fourth consecutive green Windows run.
- Backend API tests: failed with `401 !== 200` at the `/authenticator/enable` (correct code) assertion. Root cause in the test, not the server: that fetch sent a JSON body without `content-type: application/json`, so `express.json()` never parsed it and the server saw `code: undefined`. (The preceding `code:"000000"` case had passed only because it asserts 401 anyway.) Both enable calls fixed to send the header.
- Android: failed at Dart compile with `Expected a declaration, but got '}'` plus cascading `Method not found: 'request'` / `Undefined name 'mounted'` errors through the rest of the file. Root cause: the `openScanner` rewrite closed the method on its own line but the original standalone method-closing `}` was left behind, closing `_HomeState` early so `_showSessions`, `signOut` and the top-level-looking helpers fell outside the class. Stray brace removed; overall brace balance verified at 0 with the class opening at line 20 and closing only after `signOut`.
- No local app builds or tests were run.

## GitHub Actions v91 — Windows green (3rd consecutive); backend failed on a pairing insert bug (fixed); Android forensics solved the icon mystery and exposed the app-label bug

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43103743637
Commit: `d42d02a` (Manual QR short-code entry, dedicated web sign-in scan, APK forensics).

- Windows: normal-launch check and restart/reset lifecycle both passed; `Peo Yame v91 Windows` artifact uploaded. Third consecutive green Windows run.
- Backend API tests: failed. `SqliteError: 11 values for 10 columns` in `pairingCreate` — the short-code batch added `short_code_hash` to the INSERT column list but left one extra `?` placeholder. Fixed locally in `backend/src/server.js` (placeholder count now 9 + the literal `'pending'` = 10 columns).
- Android: analysis, widget tests, and the release APK build passed; the packaged-icon assertion failed again, but the new forensics changed the diagnosis entirely:
  - `aapt2 dump badging` shows the icon IS packaged: `application-icon-65534:'res/BW.xml'` across all densities.
  - The APK entry list shows obfuscated resource paths (`res/BW.xml`, `res/-B.png`, `res/0c.9.png`, …) — this toolchain's release builds enable AAPT2 resource path shortening, so filename-based assertions (`res/mipmap-xxxhdpi/ic_launcher.png`) can never match, with or without `-vN` suffixes. Prior failures from v88 on were a broken verification method, not a missing icon.
  - Badging also exposed a real defect: `application: label='monitor'` — the manifest label was left at the `flutter create` project name instead of "Peo Yame".
  - Fixes applied locally: the icon assertion now greps `aapt2 dump badging`/`dump resources` output (resource table names survive path shortening) for `mipmap/ic_launcher` with xxxhdpi and anydpi configurations; `android:label="Peo Yame"` is set explicitly; `android.enableResourceOptimizations=false` is appended so resource paths stay inspectable.
- No local app builds or tests were run.

## GitHub Actions v90 — Windows and backend green; Android APK contains no launcher resources at all

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43102420479
Commit: `14ff446` (Diagnose APK icon packaging and record v89 evidence).

- Backend API tests: passed (13s).
- Windows: normal-launch check and restart/reset lifecycle both passed; `Peo Yame v90 Windows` artifact uploaded. Second consecutive green Windows run.
- Android: analysis, widget tests, and the release APK build passed, but the packaged-icon assertion failed again. The diagnostic print returned `APK icon entries: []` — the APK contains no mipmap or launcher-named entries whatsoever, so the icon is not merely missing at one density. A full forensic dump (APK size, total entry count, res/ sample, and `aapt2 dump badging` icon lines) was added to the next run to identify what the packaged manifest actually references.
- No local app builds or tests were run.

## GitHub Actions v89 — Windows launch verification passed; Android icon packaging unresolved

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43101294712
Commit: `2004c2b` (Correct packaged icon assertion and Windows launch trace check).

- Backend API tests: passed.
- Windows: the normal-launch check passed for the first time in CI. The unmodified single executable started from a folder containing only the executable, served a live health endpoint and the dashboard, requested the dashboard URL, and completed account registration. The restart/reset lifecycle check passed. The `Peo Yame v89 Windows` single-exe artifact was uploaded.
- Android: analysis, widget tests, and the release APK build passed, but the packaged-icon assertion still failed: the APK contains no `mipmap-xxxhdpi` launcher entry under either the `-v4`-suffixed or plain path, so the resource is not being packaged as expected. A diagnostic print of the APK's mipmap/launcher entries was added ahead of the assertion to identify the actual packaged paths on the next run.
- No local app builds or tests were run.

## GitHub Actions v88 — failed (workflow check corrections applied for v89)

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43099381108
Commit: `d612ab6` (Rebuild Windows launch verification and app branding).

- Backend API tests: passed.
- Windows: publish succeeded; the new normal-launch check verified health and dashboard, then failed with "Dashboard launch not requested." The trace assertion read `launch.log` once, immediately after the first successful health poll, racing the launcher's asynchronous "Dashboard launch target" trace write, and the step did not dump trace/log contents on this failure. The launch verification now retries the trace read for up to 10 seconds and dumps the trace and app log before failing.
- Android: analysis, widget tests, and the release APK build succeeded; the new packaged-icon assertion failed because it required the APK path `res/mipmap-xxxhdpi-v4/ic_launcher.png`. AAPT2 adds the `-v4` suffix only for compatibility with minSdk below 4, and Flutter sets minSdk 21, so the branded resource is packaged as `res/mipmap-xxxhdpi/ic_launcher.png`. The assertion now accepts optional `-vN` suffixes and also verifies the round and adaptive icons.
- No Android or Windows artifacts were uploaded. No local app builds or tests were run.

## Correction: Windows startup claims for v83–v85

The user reports that the v83 Windows app did not launch its backend in normal Windows use. The prior CI result covered only the special --self-test code path and did not launch the normal tray app. v84's dashboard launch-target assertion also ran within --self-test. Those results do not establish that the actual Windows app starts correctly. The v85 normal-launch result remains unverified for the same reason. A replacement workflow is pending that starts the executable normally from a clean folder and verifies live health, dashboard HTML, and account registration. CI suppresses the visible browser window; it checks that the app requested the dashboard URL.

## GitHub Actions v77

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43081552333
Commit: `c1f01a3e737a12aebc3a880eccced887c17cabe4`.

- Backend tests: passed.
- Android widget test and analyzer: passed; Android release APK built and uploaded as `Peo Yame v77 Android`.
- Windows packaged backend lifecycle test: passed; ZIP uploaded as `Peo Yame v77 Windows`.
- This run verifies the backend regex and Android compile/API corrections. It does not cover the pending design pass, full QR security, installer, encryption, sensors, or manual visual/device checks.
- No local app builds or tests were run.

## GitHub Actions v78 — failed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43086745905
Commit: `7a29c8368d1979e0bd4a2d84f1082d77f6e39117`.

- Backend and Windows jobs failed because a static web assertion expected the mobile-only Welcome heading on the web split sign-in gate. The backend estimate assertions passed.
- Android widget compilation failed because the welcome logo container used an integer for `Container.padding` instead of `EdgeInsets`.
- Both source issues were corrected in v79. No local app builds or tests were run.

## GitHub Actions v79 — passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43087493893
Commit: `268ac26fab580ee73caa7150ade20611eda1c929`.

- Backend API tests passed, including dashboard root and estimate disclaimer checks.
- Windows tray package test passed, including startup, `/api/health`, and dashboard HTML checks. Artifact was a ZIP with separate runtime files; this is superseded by the requested standalone executable work.
- Android analysis passed and release APK artifact was produced.
- The v79 Windows lifecycle check did not observe opening the system browser; browser launch was not part of that automated self-test.
- No local app builds or tests were run.

## GitHub Actions v80 — failed during active-session implementation

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43089055834
Commit: `415515c8d28c6fdf798d3c201fc57b94e036acc5`.

- Backend test expected one session after the test had performed both registration and another successful login; actual session count was two.
- Android compilation found a parenthesis error in the new Active sessions dialog.
- Windows stopped at the same backend test failure. Both identified issues were corrected in v81.

## GitHub Actions v81 — passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43089422093
Commit: `a30686b7558ff23eab6ed31ab8fb47e8d6a0475d`.

- Backend tests passed for session listing, current-device identification, per-device revocation, revoke-other-sessions, and cross-account revocation rejection.
- Android widget test, analyzer, and release APK build passed; artifact `Peo Yame v81 Android` uploaded.
- Windows backend packaging and lifecycle self-test passed; artifact `Peo Yame v81 Windows` uploaded. This is still the ZIP format and does not verify the new standalone executable.
- No local app builds or tests were run.

## GitHub Actions v82 — Windows publish failed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43090910626
Commit: `a7e8e417d5b78492a3adf4ba4b6079bcd2a19c32`.

- Backend tests passed.
- Android analysis passed; the release build was still running when Windows publish failed.
- Windows prepared the embedded bundle, then publish failed because MSBuild resolved the relative embedded-resource paths from `windows/` and could not find `PeoYame.bundle.zip`. No standalone artifact or startup check was produced.
- The workflow now resolves the bundle and icon to absolute paths before publish. This correction is not yet CI-verified.
- No local app builds or tests were run.

## GitHub Actions v83 — passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43091285867
Commit: `d183d386ce00547924b09dc3ddb1b5be2d476150`.

- Backend tests passed.
- Windows published a 107,262,737-byte self-contained executable. The workflow copied only that executable to an isolated folder and successfully started it; its embedded runtime served both `/api/health` and the dashboard HTML, then passed account, restart, reset, and stop checks. Artifact `Peo Yame v83 Windows` uploaded.
- Android widget test, analyzer and release APK passed; artifact `Peo Yame v83 Android` uploaded.
- The executable did not yet exercise the browser-launch request; v84 adds that assertion.
- No local app builds or tests were run.

## GitHub Actions v84 — passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43092378309
Commit: `37e05713a702191d56061d6d7a118a66e23ee0f6`.

- Backend tests passed.
- Windows isolated standalone startup, embedded backend/dashboard and dashboard URL launch-request checks passed. Artifact `Peo Yame v84 Windows` uploaded (107,264,219 bytes).
- Android widget test, analyzer and release APK passed; artifact `Peo Yame v84 Android` uploaded.
- CI verified the launch request was recorded, but did not observe a visible desktop browser.
- No local app builds or tests were run.

## GitHub Actions v69

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43050967745

- Backend tests: passed.
- Android failed on Dart syntax errors, corrected in the next revision.
- Windows publish succeeded, but the lifecycle self-test step failed.

## GitHub Actions v70

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43051496142

- Backend tests: passed.
- Android syntax was corrected; the widget test revealed the demo action was below the initial welcome viewport. The welcome layout was then simplified.
- Windows self-test failed; the log output did not expose its return reason.

## GitHub Actions v71

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43052045739

- Backend tests passed.
- Android widget test and analyzer passed; release APK artifact `Peo Yame v71 Android` was uploaded (33,747,844 bytes).
- Windows self-test still failed. The next workflow uses Start-Process to read the GUI executable's actual exit code and writes a marker when its entry point starts.

## GitHub Actions v72

Pending at the time of this report. No result is claimed.

No app build or test commands were run on the development machine.

## GitHub Actions v85

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43094194736

- Backend API test job passed, including the crop-inspection reminder scenarios.
- Windows backend packaging and isolated single-executable lifecycle verification passed; artifact upload completed.
- Android test/analyzer and release build passed; APK upload was in progress at the last status check.
- v85 does not include sensor management changes; those are pending a subsequent Actions run.
- No app build or test commands were run on the development machine.

## GitHub Actions v86 (sensor management)

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43095622399

- Queued behind the v85 Android artifact upload at the time v87 source work began; no result is claimed yet.
- Includes account-owned sensor registration, location linking/unlinking, demo sensor reading and authorization coverage, and web/Android client changes.

## GitHub Actions v87 (reading exports)

Pending commit and CI. Source adds account-scoped CSV and Markdown endpoints, web downloads, Android clipboard export, and API format checks. No result is claimed yet.

## GitHub Actions v88 (Windows normal-launch and logo verification)

Pending commit and CI. The rebuilt workflow runs backend tests, Android analysis/release build plus APK launcher-resource checks, and a Windows job that launches the normal single-file app from a clean folder, verifies live backend health/dashboard/account registration, and runs lifecycle checks. The workflow also checks the approved Windows executable icon and uses the supplied Android launcher icons. No result is claimed yet.
