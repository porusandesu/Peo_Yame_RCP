# Baseline risk register

> **Current demo boundary:** Demo mode has no authentication and uses a shared
> Demo Farmer. Keep it on a controlled network and use synthetic data only;
> production authentication remains a separate flow.

Ratings are qualitative engineering assessments from repository inspection, not a completed institutional risk assessment. Reassess with the supervisor and intended site before deployment.

| ID | Risk / evidence | Likelihood / impact | Priority | Incremental treatment |
|---|---|---|---|---|
| R1 | False confidence in spoilage: one temperature/RH crossing creates an alert, but the seeded grain and fresh-produce ranges are starter guidance; there is no measured grain moisture, exposure duration, cultivar/maturity profile or spoilage observation model | High / High | Critical | Call it a condition alert; validate limits with Botswana extension officers and storage operators; measure grain moisture separately; do not call an alert confirmed spoilage |
| R2 | Readings, crops and account data persist in SQLite, but alerts/acknowledgements, incidents and simulated SMS entries are in memory and are lost on restart | Certain / High | High | Add persistence only for approved records; test restart/recovery and describe current entity-specific behavior |
| R3 | No physical sensing or calibration; all generated readings are synthetic | Certain / High | Critical | Integrate hardware and compare readings against a reference instrument; clearly label synthetic data in interim evaluations |
| R4 | “SMS” is only an in-memory `logged` entry; no provider/modem, delivery acknowledgement, or failure handling | Certain / High | Critical | Implement the approved GSM/SMS path and record queued/sent/delivered/failed states with evidence; never report simulated log entries as messages sent |
| R5 | Demo farmer/crop routes are unauthenticated and shared; production farmer routes use bearer sessions, but global monitor, alert and sensor-ingestion APIs are not farmer-scoped; default HTTP is unencrypted | High / High | Critical | Keep demo isolated and synthetic; scope global routes, define roles/device identity, deploy HTTPS, restrict CORS/network exposure, and test denial cases |
| R6 | No stale-reading logic; clients can present the last available reading as current after a source stops | High / High | High | Calculate age from `recordedAt`, set stale state, expose source/heartbeat status and test outage/recovery cases |
| R7 | Dashboard hard-codes “Synced 5 mins ago”, which can falsely imply freshness | High / Medium | High | Derive the label from a real successful sync timestamp or remove it |
| R8 | “Storage time estimate” is a handful of fixed day values based on normalized distance from threshold midpoint | High / High | High | Label explicitly as unvalidated demo heuristic or hide it; do not use it for operational decisions or research findings |
| R9 | Temperature accepts any finite number; JSON payload limits, rate limiting and abuse controls are not explicitly configured | Medium / Medium | Medium | Add plausible sensor-range/quality validation appropriate to the instrument, request size/rate controls and boundary tests |
| R10 | Action log accepts client-supplied actor/source/details, is capped, and has no integrity/authentication guarantee | Medium / Medium | Medium | Treat as demo UX telemetry only; authenticate, validate fields, protect retention and document evidentiary limitations |
| R11 | Cost and installed-cost claims lack dated quotes, purchase evidence, and a visible labour/install breakdown | High / Medium | High | Obtain and archive itemised local supplier quotes; show contingency, currency/date, landed costs, installation and sensitivity separately |
| R12 | Checked-in automated coverage includes one fresh-install widget test and an authenticator test; password/QR auth, persistence, stale data, SMS failure and performance coverage remain limited | High / High | High | Add repeatable integration/security tests and retain logs before claiming production security or performance |

The objective-to-code mapping and detailed unsupported-claim list are in [BASELINE_AUDIT.md](BASELINE_AUDIT.md). Test observations are in [TEST_REPORT.md](TEST_REPORT.md).
