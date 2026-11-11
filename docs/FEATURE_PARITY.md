# Feature parity status

The fresh clients use the same five top-level destinations: Overview, Trends, My Crops, Alerts, and Settings. Design tokens are derived from the supplied CSS and SVG references. Figma was not accessible in this session, so visual comparison remains unverified. Demo readings are labelled simulated; rough estimates use a backend heuristic and the required manual crop-check disclaimer.

Implemented and CI-verified at v77: baseline backend account/site/demo tests, Android widget/analyzer/release package, and Windows packaged tray executable/backend lifecycle test. The v77 run verified source blockers only; the current design pass is awaiting CI.

Active sessions are now implemented in source for backend, web and Android: signed-in users can view their own unexpired sessions, identify the current device, revoke a selected other session, or sign out other devices. Session metadata has an additive migration for existing SQLite databases. This change awaits GitHub Actions verification; do not call the feature verified until the backend and Android jobs pass.

Remaining parity work includes verified TOTP, sensor creation/link/unlink, CSV/Markdown export, a functional server-sent-event stream, client polling/offline recovery, inspection reminders, full Guided Demo checklist/run sheet, and accessibility/responsive checks. QR flows have backend tests but still need fuller client and security verification. Do not mark these complete without source support and GitHub Actions evidence.
