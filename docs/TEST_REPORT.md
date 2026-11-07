# Verification record

## Current build status on `pauls-branch`

The historical baseline below describes an older source state and is not evidence for the current changes. This increment adds a web demo-entry static test, a backend SQLite crop-package integration test, a Flutter demo-entry widget test, and GitHub Actions jobs for Flutter tests/analysis/APK build and Node checks/tests. Local tests and builds were intentionally not run. GitHub run [42380409390](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42380409390): backend checks passed; Flutter widget tests and Dart analysis passed; Android APK packaging failed because Gradle's 1 GiB heap was exhausted during Jetifier transforms. Gradle heap has been increased to 3 GiB for the follow-up run. The failing run produced no APK artifact.

Current scope: demo entry is direct and session-free. Phone login, account creation, and QR SSO remain unimplemented. The crop package is a starter reference; it is not locally validated postharvest advice. See [HANDOFF.md](HANDOFF.md) and [BOTSWANA_CROP_STORAGE_PACKAGE.md](BOTSWANA_CROP_STORAGE_PACKAGE.md).

**Date:** 15 October 2026  
**Target:** top-level `backend/` and Flutter app in branch `v.0.0.0.0.01`.  
**Environment:** local Node/Express demo on port 3000; Flutter SDK at `/home/porusandesu/flutter`.  
**Scope note:** the user requested a baseline audit and specific behavior checks. These are focused probes, not a full test suite or production security assessment.

## Executed checks

| Check | Result | Evidence / limitation |
|---|---|---|
| Backend starts with `npm run demo` | **Pass** | Logged `Storage monitor demo API running on http://0.0.0.0:3000`. |
| Status and synthetic 24-hour chart baseline | **Pass** | `/api/status` returned active Maize; `/api/readings/trends?range=24h` returned at least 90 points including `synthetic: true`. Baseline points are generated, not sensor observations. |
| Invalid sensor payloads | **Pass (sampled cases)** | String temperature, RH 101, and whitespace-only site returned HTTP 400. This does not establish exhaustive schema validation. |
| Valid sensor payload and in-range no-alert case | **Pass** | Maize reading 19 °C / 50% RH accepted with HTTP 201 and no alert. |
| Crop mismatch and unsupported crop | **Pass** | Maize-active request tagged Tomato returned HTTP 409; selecting unsupported Lettuce returned HTTP 400. |
| Crop threshold switch | **Pass** | Selecting Tomato returned limits 10–20 °C / 85–95% RH. |
| Threshold breach creates alert | **Pass** | Tomato reading 21 °C / 90% RH returned HTTP 201 and an unacknowledged alert (`Threshold breached: 21°C, 90% RH`). This verifies a configured-bound crossing only. |
| SMS failure/delivery behavior | **Not applicable / unsupported** | The only observable result is an in-memory log with `status: "logged"`; there is no network dispatch, modem, delivery receipt or failure path to test. |
| API access control | **Not present** | Code inspection: no auth middleware or authorization checks, unrestricted `cors()`, plain HTTP, all-interface bind. No positive access-control result can be claimed. |
| Stale sensor reading behavior | **Not implemented** | No age/staleness evaluation in `/api/status`; any newest in-memory reading is returned. This was established by source inspection, not an outage test. |
| Persistence of domain records | **Not implemented** | Readings/alerts/incidents are process-memory arrays. Only action history is appended to JSONL. No SQLite DB or restart persistence test exists. |
| CSV export contract | **Pass (smoke)** | `/api/readings/export.csv` returned CSV containing `threshold_breach`; probe checked header shape only, not exhaustive escaping/formula-injection cases. |
| Flutter widget test | **Blocked before test execution** | `flutter test --no-pub` exited 1: “Package(s) objective_c require the native assets feature to be enabled.” `flutter test` without `--no-pub` stalled at dependency resolution and was interrupted. This is environment/tool setup, not a widget assertion failure. |
| Performance/latency | **Not measured** | No benchmark harness or recorded timing evidence. Do not claim response latency, throughput, or alert-delivery speed. |

The API probes temporarily changed the running demo's in-memory active crop and added sample readings/alerts. Restarting its process resets these demo values. The persistent action log can include the test-generated harvest/sensor events. No source code was changed to execute the checks.

## Test inventory and remaining verification

The only checked-in Flutter test is `test/widget_test.dart`, a generated scaffold assertion for the text “Storage Monitor”; it is stale relative to the Peo Yame product wording and could not run in this environment. `backend/package.json` has no `test` script and no backend test files are present in the top-level project.

Before research evaluation, add repeatable backend tests for inclusive/exclusive boundary semantics, missing/null/non-finite values, temperature plausibility, timestamp validity and staleness, per-crop rule selection, alert acknowledgement, bounded retention, restart persistence, malformed/oversized JSON, export escaping, CORS/auth denial cases, SMS failure states, and simulator outage/recovery. Add current-client widget tests. Store command output and fixture data with the project; only then report measurements. See [BASELINE_AUDIT.md](BASELINE_AUDIT.md) for the incremental plan.
