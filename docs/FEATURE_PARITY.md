# Feature parity status

## Security hardening and trend charts — v117 CI verified

The current continuation externalizes dashboard HTML assets and removes inline
event/style attributes so the dashboard can use a per-response nonce-based
strict CSP. Authenticator enable/disable rotates the active token/cookies and
revokes other sessions. Security activity now includes failed sign-ins,
lockouts, QR outcomes, and session expiry, with visible loading states on both
clients. Trend charts now share time ranges, labelled value/time axes, units,
target-band shading, timestamps, accessible summaries, and exact low/high
statistics. The API returns at most 500 plotted samples while preserving full
range summaries and extrema. Focused API/static-asset tests were added. GitHub
Actions v115 (run [`43233949692`](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43233949692),
commit `dba7c9c`) passed backend API tests, Android tests/analysis/release APK,
and Windows launch/lifecycle/installer checks. No local application builds or
tests were run. Windows Firewall, real-device LAN access, camera permissions,
and manual visual/accessibility checks remain open.

## Design defect dispositions — 34-row source audit

The design-reference §11 rows were checked against the current source. “Already
fixed” means the source contains the requested behavior; CI evidence applies
where cited, and does not replace manual visual, accessibility, camera, or
physical-device verification. Rows changed after v115 are marked pending the
next Actions run.

| # | Disposition | Source/test evidence |
|---|---|---|
| 1 | Already fixed | Phone/password, demo, and QR sign-in: `backend/public/index.html`, `mobile/lib/main.dart`; backend auth tests |
| 2 | Already fixed | Name/phone/password/confirmation registration: web and mobile auth screens; backend registration tests |
| 3 | Already fixed; latest CI pending | Single mobile QR action and separate backend setup: `mobile/lib/main.dart`; `mobile/test/widget_test.dart` |
| 4 | Already fixed | Demo entry points: web and mobile auth screens; Guided Demo backend tests |
| 5 | Already fixed | Five mobile destinations with Accounts in Settings: `mobile/lib/main.dart`; widget tests |
| 6 | Already fixed | Week-range rough-estimate card and disclaimer: `backend/public/app.js`, `mobile/lib/main.dart`; estimate tests |
| 7 | Already fixed | Overview uses the same estimate and “In range” status: web and mobile dashboard sources |
| 8 | Already fixed; latest CI pending | “In range”/“Target range” and crop-safety disclaimer: `backend/public/app.js`, `mobile/lib/main.dart` |
| 9 | Already fixed | Low/Target/High indicators: web and mobile status-card sources |
| 10 | Already fixed | Phone/password account wording: mobile account/settings source |
| 11 | Already fixed | Crop/sensor summaries derive from owned backend records: web/mobile crop screens; backend ownership tests |
| 12 | Already fixed | Refresh control does not split mid-word: mobile Settings layout |
| 13 | Already fixed | Web controls have visible text/accessible labels: `backend/public/index.html`, `backend/public/app.js` |
| 14 | Already fixed | Flow A approval dialog and “Connect phone by QR” in Settings: `backend/public/guided-demo.js`, `backend/public/app.js` |
| 15 | Already fixed | No local one-time-PIN delivery promise: web sign-in and alert text |
| 16 | Already fixed | Alert panel states SMS is not sent: web and mobile alert screens |
| 17 | Already fixed | Matching trend series, axes, units, bands, ranges and summaries: web/mobile chart sources; trend API tests |
| 18 | Already fixed | Shared backend last-sync timestamp/format: web and mobile sync status |
| 19 | Already fixed | Account display and Botswana phone formatting: web and mobile account screens |
| 20 | Already fixed; latest CI pending | Separate “Add crop to monitor” and “Add storage location”: `backend/public/app.js`, `mobile/lib/main.dart` |
| 21 | Already fixed | Five web destinations: `backend/public/app.js` |
| 22 | Already fixed; latest CI pending | Settings refresh and web download/mobile clipboard CSV/Markdown actions: web and mobile Settings |
| 23 | Already fixed | Phone waits for computer approval and displays match number: mobile QR flow; pairing API tests |
| 24 | Already fixed | Web Flow A device/match-number approval dialog: `backend/public/guided-demo.js` |
| 25 | Already fixed | Match-number and verifier-bound pairing flows: backend parity tests; web/mobile QR sources |
| 26 | Already fixed | Camera rationale and manual code entry: `mobile/lib/main.dart`; widget/pairing tests |
| 27 | Already fixed | Active sessions, revoke and sign-out-everywhere: web/mobile settings; backend session tests |
| 28 | Already fixed | Guided Demo and demo tools: web/mobile settings; simulator tests |
| 29 | Already fixed; latest CI pending | Rough estimate on web alerts and mobile cards: `backend/public/app.js`, `mobile/lib/main.dart`; estimate tests |
| 30 | Already fixed | Input border token `#768A80`: shared web/mobile design tokens |
| 31 | Already fixed | Active web tab uses primary brand token: `backend/public/styles.css` |
| 32 | Already fixed | Status chips pair state color with a leading icon: web/mobile status components |
| 33 | Already fixed | “Welcome to / Peo Yame” heading and separate setup screen: `mobile/lib/main.dart`; widget test |
| 34 | Already fixed | Approved logo packaged for Android/Windows and used by web: asset resources; packaging CI |

The follow-up for rows 3, 8, 20, 22 and 29 is not included in v115 and still
needs a fresh Actions run. Visual design comparison, keyboard/screen-reader
accessibility, camera permission prompts, and real-device LAN behavior remain
manual checks.

## Guided Demo Settings refresh and presentation — v114 CI verified

The manual refresh action is now in Settings on both web and mobile; automatic
live sync remains active, and mobile pull-to-refresh is retained. Mobile
Settings is regrouped into styled sections, while web Settings uses responsive
cards and keeps the Guided Demo controls available. GitHub Actions v114 (run
[`43224956617`](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43224956617),
commit `f73378d`) passed backend API tests, Android tests/analysis/release
APK, and Windows launch/lifecycle/installer checks. Real-device/browser
visual and accessibility review remains open.

## Guided Demo refresh, privacy and custom crops — v112 CI verified

Guided Demo now produces changing temperature and humidity readings every
3 seconds, sends an immediate reading on start, and schedules crop-band
outliers that generate account-scoped simulated alerts. The alerts stream to
paired web and Android sessions. Web and mobile let users add a crop, fruit,
or vegetable and select it after saving. Backend addresses and QR approval
network addresses are masked by default with an explicit reveal action; the
mobile Welcome screen no longer exposes backend configuration, while its QR
sign-in action still supports first-time backend-connection QR codes.

GitHub Actions v112 (run
[`43222452877`](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43222452877),
commit `c806d9a`) passed backend tests, Android tests/analysis/release APK,
and Windows normal launch, restart/reset, installer, encrypted-storage, and
uninstall checks. Artifacts `Peo Yame v112 Android` and
`Peo Yame v112 Windows` were uploaded. Visual presentation, camera
permissions, and real-device/Wi-Fi behavior remain unverified.

## QR and backend pairing — v109 CI verified

Guided Demo now starts with an empty location list and an unlinked synthetic
sensor, and its generated password is shown once so the real password and
authenticator re-checks remain usable during the demo. Phone QR creation
requires the same re-authentication in demo and normal accounts. The web
dashboard now uses a real Flow A approval dialog, expiring QR countdown and
renewal, and an address-only backend QR. Mobile offers QR sign-in from Welcome,
camera-permission recovery, manual pairing-code entry, and an explicit
verifier-bound cancel action.

GitHub Actions v109 (run
[`43211211135`](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43211211135),
commit `fc7f261`) passed backend API tests, Android tests/analysis/release APK
and packaged launcher verification, and Windows normal launch, restart/reset,
installer, encrypted-storage acceptance, and uninstall. Artifacts
`Peo Yame v109 Android` (71,407,319 bytes) and `Peo Yame v109 Windows`
(311,284,357 bytes) were uploaded. No local app builds or tests were run.
Browser interaction, visual/accessibility, camera permissions, and
real-device/Wi-Fi behavior remain unverified.

## Session security and demo sync — v107 verified

The v100 browser-origin, CSRF, QR, and authenticator hardening passed
GitHub Actions; v102 (run `43197194366`, commit `6aaf89e`) additionally verified
30-minute idle expiry for password and phone QR sessions across backend,
Android, and Windows jobs. v103 (run `43199378655`, commit `fa6cf58`) passed
account+IP lockout and shared Guided Demo simulation tests, plus Android and
Windows checks. v104 (run `43200357299`, commit `d3488d6`) verified the
two-hour absolute lifetime for QR-created Guided Demo sessions across all
three jobs. v107 (run `43203834344`, commit `1a5aa56`) verified revoking
other sessions after authenticator enable/disable while retaining the current
session. The source applies 30-minute idle expiry to every session type and
closes idle event streams.

At the v107 audit snapshot, dashboard CSP was disabled for inline scripts and
handlers, and the activity feed did not yet record failed sign-ins or lockouts.
Those are historical gaps; the current unverified work is tracked at the top
of this document.
The verified source adds five-failure phone+IP lockout for 15 minutes within a
rolling 15-minute window, plus a server-side 3-second Guided Demo simulator,
QR sharing across mobile/web, and event-driven refresh for every screen. QR
sessions are capped at the demo profile's two-hour absolute lifetime, and
other sessions are revoked when the authenticator is enabled or disabled.
Windows Firewall behavior, real-device LAN access, and manual
visual/accessibility checks remain unverified. CI passing is not an independent
security review.

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

At the v87 snapshot, the remaining work included TOTP, exports, events, client
recovery, Guided Demo checklist, and accessibility checks. Later verified
sections above supersede that historical list; manual device/browser and
accessibility checks are still open.

Sensor account records, linking/unlinking, per-account authorization, sensor readings, and simulated demo sensor data are now implemented in source for web, Android, and backend. Physical pairing/discovery is not implemented; the web UI states this. Backend coverage and Android compilation are pending the next GitHub Actions run. Sensor history uses the location captured when each reading arrives; pre-link readings without a location can appear after linking.

CSV and Markdown exports are now implemented in source. The backend scopes downloads to the current account (and keeps the shared anonymous demo on shared demo rows); web downloads files, while Android copies the selected format to the clipboard. Export API coverage and Android compile evidence are pending v87 CI.

## Feature-parity implementation — automated CI complete

The current `copilot/feature-parity` worktree adds per-user SSE mutation events, reconnecting/offline recovery in web and Android, the 30-item Botswana-oriented starter catalog with account-owned custom entries and persisted crop selection, Android biometric app lock, password plus enabled-TOTP re-check for phone pairing creation, SQLCipher-backed database encryption with plaintext migration, and a per-user Windows installer. Automated source tests cover event delivery, catalog counts/custom-crop isolation/selection, pairing re-authentication, and database migration, ciphertext, wrong-key rejection, reopening, and encrypted-copy recovery.

GitHub Actions v97 (run `43173464542`, commit `2c1bac6`) passed backend tests, Android widget tests/analysis/release APK and launcher verification, and Windows normal launch, restart/reset, installer installation/launch, encrypted-storage acceptance, and uninstall. Artifacts `Peo Yame v97 Android` and `Peo Yame v97 Windows` were uploaded. No local application tests/builds have been run. The catalog documentation explicitly notes that Statistics Botswana does not publish a ranked top-ten list for all three catalog categories; the selection is evidence-informed and Botswana-oriented, not a measured popularity ranking. Manual visual/accessibility and real-device verification remain open.
