# Feature parity status

The fresh clients use the same five top-level destinations: Overview, Trends, My Crops, Alerts, and Settings. Design tokens are derived from the supplied CSS and SVG references. Figma was not accessible in this session, so visual comparison remains unverified. Demo readings are labelled simulated; rough estimates use a backend heuristic and the required manual crop-check disclaimer.

CI v81 verified backend account/site/demo tests, active-session list/revocation and account isolation, Android widget/analyzer/release APK, and Windows packaged backend lifecycle. Its Windows artifact still used a ZIP with external backend files; the user has asked for a single executable, now in progress and pending CI.

Active sessions are implemented in backend, web and Android: signed-in users can view their own unexpired sessions, identify the current device, revoke a selected other session, or sign out other devices. Session metadata has an additive migration for existing SQLite databases. GitHub Actions v81 passed backend tests for list, revoke, and account isolation, plus the Android widget test/analyzer/release build. No manual UI observation was performed.

The Windows launcher is a single self-contained executable with its Node.js runtime, SQLite native module, backend, web dashboard, and icon embedded. v83 passed an isolated executable test covering runtime extraction, backend health, dashboard HTML, account persistence, reset, and stop. The test has not yet observed a desktop browser; a follow-up will assert the dashboard URL launch request. The preceding ZIP build is not the delivery format for this change.

Remaining parity work includes verified TOTP, sensor creation/link/unlink, CSV/Markdown export, a functional server-sent-event stream, client polling/offline recovery, inspection reminders, full Guided Demo checklist/run sheet, and accessibility/responsive checks. QR flows have backend tests but still need fuller client and security verification. Do not mark these complete without source support and GitHub Actions evidence.
