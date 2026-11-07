# Baseline risk register

Ratings are qualitative engineering assessments from repository inspection, not a completed institutional risk assessment. Reassess with the supervisor and intended site before deployment.

| ID | Risk / evidence | Likelihood / impact | Priority | Incremental treatment |
|---|---|---|---|---|
| R1 | False confidence in spoilage: one temperature/RH crossing creates an alert, but limits are illustrative and there is no moisture, duration, stage or spoilage observation model | High / High | Critical | Rename as threshold condition alert; validate crop/stage limits; include grain moisture where relevant; do not call alert confirmed spoilage |
| R2 | No persistence for readings, alerts, incidents or thresholds; restart loses these records | Certain / High | Critical | Add and test SQLite storage for agreed domain records before collecting project evidence |
| R3 | No physical sensing or calibration; all generated readings are synthetic | Certain / High | Critical | Integrate hardware and compare readings against a reference instrument; clearly label synthetic data in interim evaluations |
| R4 | “SMS” is only an in-memory `logged` entry; no provider/modem, delivery acknowledgement, or failure handling | Certain / High | Critical | Implement the approved GSM/SMS path and record queued/sent/delivered/failed states with evidence; never report simulated log entries as messages sent |
| R5 | API has no authentication or authorization, unrestricted CORS, plain HTTP, and listens on all interfaces; anyone on reachable network may read or mutate demo data | High / High | Critical | Keep isolated for demo; define threat model, authenticate clients, authorize writes, restrict CORS/network exposure, protect transport and test denial cases |
| R6 | No stale-reading logic; clients can present the last available reading as current after a source stops | High / High | High | Calculate age from `recordedAt`, set stale state, expose source/heartbeat status and test outage/recovery cases |
| R7 | Dashboard hard-codes “Synced 5 mins ago”, which can falsely imply freshness | High / Medium | High | Derive the label from a real successful sync timestamp or remove it |
| R8 | “Storage time estimate” is a handful of fixed day values based on normalized distance from threshold midpoint | High / High | High | Label explicitly as unvalidated demo heuristic or hide it; do not use it for operational decisions or research findings |
| R9 | Temperature accepts any finite number; JSON payload limits, rate limiting and abuse controls are not explicitly configured | Medium / Medium | Medium | Add plausible sensor-range/quality validation appropriate to the instrument, request size/rate controls and boundary tests |
| R10 | Action log accepts client-supplied actor/source/details, is capped, and has no integrity/authentication guarantee | Medium / Medium | Medium | Treat as demo UX telemetry only; authenticate, validate fields, protect retention and document evidentiary limitations |
| R11 | Cost and installed-cost claims lack dated quotes, purchase evidence, and a visible labour/install breakdown | High / Medium | High | Obtain and archive itemised local supplier quotes; show contingency, currency/date, landed costs, installation and sensitivity separately |
| R12 | Existing automated coverage is one scaffold widget test; API security, persistence, stale data, SMS failure, and performance lack recorded test results | High / High | High | Add focused tests and retain logs/reproducible harness output before claiming quality/performance |

The objective-to-code mapping and detailed unsupported-claim list are in [BASELINE_AUDIT.md](BASELINE_AUDIT.md). Test observations are in [TEST_REPORT.md](TEST_REPORT.md).
