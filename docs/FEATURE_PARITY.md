# Feature parity status

## Session security and demo sync — v102 verified; next changes pending

The v100 browser-origin, CSRF, QR, and authenticator hardening passed
GitHub Actions; v102 (run `43197194366`, commit `6aaf89e`) additionally verified
30-minute idle expiry for password and phone QR sessions across backend,
Android, and Windows jobs. The source now applies that idle policy to every
session type and closes idle event streams.

Remaining audit gaps: the dashboard still disables CSP because it uses inline
scripts and handlers; the security log is incomplete and not exposed in
Settings; and authenticator changes do not rotate or revoke existing sessions.
Unpushed source changes add five-failure phone+IP lockout for 15 minutes within
a rolling 15-minute window, plus a server-side 10-second Guided Demo simulator,
QR sharing across mobile/web, and event-driven refresh for every screen.
Focused backend tests are added; CI verification is pending. Windows Firewall
behavior, real-device LAN access, and manual visual/accessibility checks remain
unverified. CI passing is not an independent security review.

The audit notes below include historical pending statuses; the v100 result
above supersedes those entries for the latest source.

## Audit batch status — 2026-11-12

- TOTP authenticator (setup/enable/disable, login gating, approval gating, session inheritance) is implemented in backend with RFC 6238 verification; web and mobile clients expose setup/enable/disable and login code entry. **CI-proven at v94** (run `43160038257`): setup/enable with a correct code → 200 and wrong code → 401, login requires a code, TOTP-re-authenticated approval works, sessions expose `totpVerified`, disable is password-gated (wrong → 401, correct → 200).
- Android launcher branding is CI-verified at v97 (run `43173464542`): packaged launcher verification passed with the release APK.
- Windows normal-launch, restart/reset lifecycle, installer acceptance, and encrypted-storage checks passed at v97 (run `43173464542`).
- Session absolute lifetimes in `backend/src/server.js`: password 168h, phone
  QR 24h, web QR 8h, and demo 2h. All session types now have 30m idle expiry;
  browser cookies follow their session's hard lifetime.
- SSE live events and client reconnect/offline recovery, the 30-item catalog and user additions, biometric app lock, pairing re-authentication, encrypted database migration/recovery, and the Windows installer are implemented and covered by the v97 CI run. Manual visual/accessibility and real-device verification remain open.

## Windows launch and logo correction (2026-11-11)

The user reports that the v83 Windows app did not launch its backend in normal use. The v83 CI result exercised only the special self-test path; it did not test the normal tray launcher. The v84 dashboard URL assertion also came from self-test. Therefore v83–v85 are not evidence that normal Windows app startup works. A replacement workflow is pending and will launch the exe normally from a clean folder, then check its live health endpoint, dashboard, and account registration. CI suppresses opening a visible browser window, so desktop browser display remains unobserved.

The supplied Android density-specific/adaptive icon resources and Windows ICO are now wired to the APK launcher and both Windows executable/tray icon. Packaging verification is pending.

The fresh clients use the same five top-level destinations: Overview, Trends, My Crops, Alerts, and Settings. Design tokens are derived from the supplied CSS and SVG references. Figma was not accessible in this session, so visual comparison remains unverified. Demo readings are labelled simulated; rough estimates use a backend heuristic and the required manual crop-check disclaimer.

CI v81 verified backend account/site/demo tests, active-session list/revocation and account isolation, Android widget/analyzer/release APK, and Windows packaged backend lifecycle. Its Windows artifact still used a ZIP with external backend files; the user has asked for a single executable, now in progress and pending CI.

Active sessions are implemented in backend, web and Android: signed-in users can view their own unexpired sessions, identify the current device, revoke a selected other session, or sign out other devices. Session metadata has an additive migration for existing SQLite databases. GitHub Actions v81 passed backend tests for list, revoke, and account isolation, plus the Android widget test/analyzer/release build. No manual UI observation was performed.

The Windows launcher is a single self-contained executable with its Node.js runtime, SQLite native module, backend, web dashboard, and icon embedded. v83 passed isolated runtime extraction, backend health, dashboard HTML, account persistence, reset, and stop checks. v84 also passed the check that the standalone app requests opening the dashboard URL. CI did not launch a visible browser window; that remains unobserved. The Windows artifact is a single `.exe`, not a ZIP containing application files.

Crop inspection reminders are implemented in source: each owned storage location is due every three days by default, site-linked readings outside target bands prompt “Check your crop now,” and “I checked my crop” records a server timestamp and resets the reminder. v85 backend tests passed; Android compile/analyzer/release also passed, but the inspection UI was not manually exercised.

Remaining parity work includes verified TOTP, CSV/Markdown export, a functional server-sent-event stream, client polling/offline recovery, full Guided Demo checklist/run sheet, and accessibility/responsive checks. QR flows have backend tests but still need fuller client and security verification. Do not mark these complete without source support and GitHub Actions evidence.

Sensor account records, linking/unlinking, per-account authorization, sensor readings, and simulated demo sensor data are now implemented in source for web, Android, and backend. Physical pairing/discovery is not implemented; the web UI states this. Backend coverage and Android compilation are pending the next GitHub Actions run. Sensor history uses the location captured when each reading arrives; pre-link readings without a location can appear after linking.

CSV and Markdown exports are now implemented in source. The backend scopes downloads to the current account (and keeps the shared anonymous demo on shared demo rows); web downloads files, while Android copies the selected format to the clipboard. Export API coverage and Android compile evidence are pending v87 CI.

## Feature-parity implementation — automated CI complete

The current `copilot/feature-parity` worktree adds per-user SSE mutation events, reconnecting/offline recovery in web and Android, the 30-item Botswana-oriented starter catalog with account-owned custom entries and persisted crop selection, Android biometric app lock, password plus enabled-TOTP re-check for phone pairing creation, SQLCipher-backed database encryption with plaintext migration, and a per-user Windows installer. Automated source tests cover event delivery, catalog counts/custom-crop isolation/selection, pairing re-authentication, and database migration, ciphertext, wrong-key rejection, reopening, and encrypted-copy recovery.

GitHub Actions v97 (run `43173464542`, commit `2c1bac6`) passed backend tests, Android widget tests/analysis/release APK and launcher verification, and Windows normal launch, restart/reset, installer installation/launch, encrypted-storage acceptance, and uninstall. Artifacts `Peo Yame v97 Android` and `Peo Yame v97 Windows` were uploaded. No local application tests/builds have been run. The catalog documentation explicitly notes that Statistics Botswana does not publish a ranked top-ten list for all three catalog categories; the selection is evidence-informed and Botswana-oriented, not a measured popularity ranking. Manual visual/accessibility and real-device verification remain open.
