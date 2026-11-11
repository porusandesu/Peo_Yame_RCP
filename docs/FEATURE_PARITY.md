# Feature parity status

The fresh clients use the same five top-level destinations: Overview, Trends, My Crops, Alerts, and Settings. The design tokens are derived from the supplied SVG references. Demo readings are labelled simulated; rough estimates include manual crop-check language and use a backend heuristic.

Implemented and CI-verified at v73: baseline backend account/site/demo tests, Android smoke test and release package, Windows packaged tray executable and backend lifecycle test.

QR pairing is currently being implemented and is not yet CI-verified. The complete prompt also requires verified TOTP, session list/revocation, sensor creation/link/unlink, CSV/Markdown export, server-sent events, client polling/offline recovery, inspection reminders, full Guided Demo checklist/run sheet, and accessibility/responsive checks. Do not mark these complete without source support and GitHub Actions evidence.
