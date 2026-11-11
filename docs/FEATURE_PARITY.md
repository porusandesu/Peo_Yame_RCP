# Feature parity status

The fresh clients use the same five top-level destinations: Overview, Trends, My Crops, Alerts, and Settings. Design tokens are derived from the supplied CSS and SVG references. Figma was not accessible in this session, so visual comparison remains unverified. Demo readings are labelled simulated; rough estimates use a backend heuristic and the required manual crop-check disclaimer.

Implemented and CI-verified at v77: baseline backend account/site/demo tests, Android widget/analyzer/release package, and Windows packaged tray executable/backend lifecycle test. The v77 run verified source blockers only; the current design pass is awaiting CI.

QR pairing is currently being implemented and is not yet CI-verified. The complete prompt also requires verified TOTP, session list/revocation, sensor creation/link/unlink, CSV/Markdown export, server-sent events, client polling/offline recovery, inspection reminders, full Guided Demo checklist/run sheet, and accessibility/responsive checks. Do not mark these complete without source support and GitHub Actions evidence.
