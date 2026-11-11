# Feature parity status

The fresh clients use the same five top-level destinations: Overview, Trends, My Crops, Alerts, and Settings. Design tokens are derived from the supplied CSS and SVG references. Figma was not accessible in this session, so visual comparison remains unverified. Demo readings are labelled simulated; rough estimates use a backend heuristic and the required manual crop-check disclaimer.

CI v81 verified backend account/site/demo tests, active-session list/revocation and account isolation, Android widget/analyzer/release APK, and Windows packaged backend lifecycle. Its Windows artifact still used a ZIP with external backend files; the user has asked for a single executable, now in progress and pending CI.

Active sessions are implemented in backend, web and Android: signed-in users can view their own unexpired sessions, identify the current device, revoke a selected other session, or sign out other devices. Session metadata has an additive migration for existing SQLite databases. GitHub Actions v81 passed backend tests for list, revoke, and account isolation, plus the Android widget test/analyzer/release build. No manual UI observation was performed.

The Windows launcher is a single self-contained executable with its Node.js runtime, SQLite native module, backend, web dashboard, and icon embedded. v83 passed isolated runtime extraction, backend health, dashboard HTML, account persistence, reset, and stop checks. v84 also passed the check that the standalone app requests opening the dashboard URL. CI did not launch a visible browser window; that remains unobserved. The Windows artifact is a single `.exe`, not a ZIP containing application files.

Crop inspection reminders are implemented in source: each owned storage location is due every three days by default, site-linked readings outside target bands prompt “Check your crop now,” and “I checked my crop” records a server timestamp and resets the reminder. Backend tests and both client UI changes are pending CI verification.

Remaining parity work includes verified TOTP, sensor creation/link/unlink, CSV/Markdown export, a functional server-sent-event stream, client polling/offline recovery, inspection reminders, full Guided Demo checklist/run sheet, and accessibility/responsive checks. QR flows have backend tests but still need fuller client and security verification. Do not mark these complete without source support and GitHub Actions evidence.
