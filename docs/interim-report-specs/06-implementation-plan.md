# Implementation Plan — Front End and Back End

> **Current runtime update (7 Nov 2026):** Demo-mode authentication and
> verification are removed. Both clients open the shared Demo Farmer directly;
> production auth/QR SSO remain. Earlier login tasks below are historical.

> **Historical planning snapshot (24 October 2026).** Tasks and implementation status reflect an earlier checkout. Reconcile completion claims with current code and the [test report](../TEST_REPORT.md); keep this file as planning history.

> **Later implementation update (7 November 2026):** A built-in Botswana crop
> catalog now covers grains, pulses, oilseeds, vegetables and fruit, with
> grouped selection and storage guidance in farmer crop setup. It has not yet
> been integration tested or evaluated with farmers. See the
> [crop package](../BOTSWANA_CROP_STORAGE_PACKAGE.md) for data provenance and
> the proposed low-literacy workflow.

**Product:** Peo Yame storage-monitoring prototype
**Purpose:** Turn requirements into a staged, demonstrable plan for Interim Report 2.
**Status:** Working plan aligned to the current top-level Flutter/Express checkout. Dates and owners must be agreed by Group 3 and reconciled with the official schedule. A task is not complete merely because code exists; collect run evidence.

> **Scope guard:** Project context says software simulation is the validation route because physical hardware cannot be procured. Do not claim calibration, real GSM delivery or a field pilot unless access changes and the supervisor approves. Predictive/ML forecasting is outside current scope. The inspected backend has SQLite tables for crops/settings/readings; alerts, SMS log and incidents remain in memory. Recheck the exact submitted revision because older notes differ.

## 1. Objectives

- Deliver a coherent demonstrator aligned with approved research objectives.
- Separate implementation, simulation and future work in code and reporting.
- Stabilize data provenance and API behavior before UI polish/evaluation.
- Produce reproducible evidence for requirements, design, implementation and tests.
- Address security gaps or explicitly constrain the demo boundary.

## 2. Delivery strategy

Use short, reviewable increments. Confirm proposal scope and API/data decisions first; stabilize backend truth and frontend states next; evaluate only what the approved environment supports. Each increment needs an owner, acceptance criteria, evidence and report-status update. Avoid hardware/cloud work without access, budget and approval.

## 3. Work breakdown structure

| ID | Work package | Front-end work | Back-end/data work | Deliverable/evidence |
|---|---|---|---|---|
| WP0 | Proposal and baseline reconciliation | Confirm active screens/current behavior | Confirm branch, routes, schema, runtime, persistence | Approved objective matrix; commit/hash; baseline inventory |
| WP1 | Requirements and contracts | Map screen actions to requirement IDs | Freeze request/response, validation and status semantics | PRD/TRD, API samples, traceability matrix |
| WP2 | Provenance and demo truth | Persistent simulation/source/time/status text, synthetic legend, remove misleading heuristic | Preserve source in storage/export; mark dispatch as logged/not sent | Screenshots and JSON/CSV examples |
| WP3 | Persistence and integrity | Display saved/error status accurately | Decide whether alerts/incidents/dispatch need durable storage; transactions/retention | Restart evidence; schema/ER diagram |
| WP4 | Core UI state coverage | Overview, Trends, Alerts, Settings; loading/offline/empty/error/success | Stable API errors/events/crop behavior | Scenario walkthrough |
| WP5 | Security boundary | Mark demo login/controls; avoid sensitive data; show connection caveat | Restrict network/CORS; protect/disable writes; add auth only if approved | Threat model, permission matrix, negative tests or documented limitation |
| WP6 | Verification | Current UI/widget flow checks and exports | API/boundary/restart/validation tests | Test matrix with expected/actual/pass-fail and logs |
| WP7 | Evaluation/report assembly | Scenario review if approved | Report only measured technical metrics | Objective-to-evidence map and limitations |
| WP8 | Release/demo readiness | Android/web demonstration and screenshots | Setup, backup/reset, startup/shutdown, config | Reproducible demo guide, build evidence and walkthrough |

## 4. Back-end work plan

### BE-0 — Confirm and baseline current build

**Activities:** identify exact working tree/commit; inspect backend/server.js, database.js, package manifest, data files and active routes; label synthetic records; do not use nested/stale copies accidentally.
**Acceptance:** report identifies correct source path/version and durable vs volatile entities. Older docs are reconciled rather than copied uncritically.
**Evidence:** commit/hash, API samples, schema inspection, baseline audit update.

### BE-1 — Data contract and validation

**Activities:** document each route, method, body and status; define allowed fields, units, UTC timestamps and source values; add temperature plausibility/date checks only after requirements are agreed; reject unknown/bad values safely; preserve client-dependent response shapes.
**Acceptance:** valid and invalid cases behave predictably; rejected requests cause no reading/alert side effect; clients can present useful errors.
**Evidence:** cases at min/max and just outside temperature/RH bounds; RH 0/100/outside; null/string values; long site/crop; unknown crop; invalid dates.

### BE-2 — Durable event/data model

**Activities:** decide whether alerts, acknowledgements, notification attempts, incidents and action events must persist. If so, migrate to a transactional SQLite schema with foreign keys, indexes, migrations/versioning. Preserve the exact threshold version or value snapshot used by each alert.
**Acceptance:** selected entities survive restart and remain linked; retry does not duplicate events; backup/restore documented.
**Evidence:** ER diagram, DDL/migration, before/after IDs/counts, restart logs and restore check.

### BE-3 — Reading and alert pipeline

**Activities:** keep validation → persistence → threshold rule → alert event deterministic; document boundary semantics; separate rule logic from route where useful; define alert idempotency/deduplication. Make synthetic generation deterministic in test mode and separate from future device input.
**Acceptance:** boundary tests have expected outcomes; breach creates expected event; no-breach creates none; source provenance survives.
**Evidence:** test output and paired reading/alert records.

### BE-4 — Availability, operations and API limits

**Activities:** handle DB failure without process crash or false success; set body/query limits, timeouts, rate limits and SSE connection limits; safe logging; health/readiness behavior; repeatable demo reset/seed process.
**Acceptance:** safe failure/recovery, bounded requests, no false persistence indication.
**Evidence:** controlled DB failure, oversized input, reconnect test, redacted logs and setup guide.

### BE-5 — Security implementation gate

**Activities:** choose local-only containment or auth scope. For local-only demo, bind/network/firewall/CORS to expected clients. If auth is in scope, add server identity, roles and device credentials. Protect all mutating endpoints; use HTTPS beyond isolated demo; gate export and demo-breach routes.
**Acceptance:** route permissions work and negative tests pass, or constraints are explicitly reported and demo remains isolated. No request actor is treated as identity.
**Evidence:** threat model, middleware/config, unauthorized and wrong-role results.

### BE-6 — SMS adapter boundary

**Activities:** keep dispatch interface separate from rule logic. Current adapter is a simulated log. Define future outcomes, retry, idempotency and privacy. Real service only with access, consent/approval and budget.
**Current demo acceptance:** no external send; log says simulation/not sent.
**Future provider acceptance:** queued/submitted/delivered/failed distinct, retry bound and duplicate prevention.
**Evidence:** current dispatch entry and UI capture; never call this delivery evidence.

### BE-7 — Phone authentication and OTP (only if approved and resourced)

**Activities:** specify account registration/approval, phone ownership, OTP provider, consent, expiry, attempts, resend cooldown, recovery, session mechanism and deletion. Implement request/verify/logout endpoints and server-side authorization; store no raw PIN. If no SMS service or time is available, retain the Figma flow as a clearly labeled concept and do not simulate a successful verified identity in the assessed application.
**Acceptance:** invalid, expired, replayed and over-attempted PINs fail; successful challenge creates a server-authenticated session; logout revokes it; credentials and PINs never appear in logs or exports.
**Evidence:** sequence/route spec, privacy/approval record, negative tests and redacted success walkthrough. No SMS sent claim without provider evidence.

### BE-8 — Farmer accounts and multiple sensor assignments (only if approved)

**Activities:** model farmer account, storage site, device registry, device credential/provisioning and crop-sensor assignment history. Add account-scoped list/search/filter APIs and per-device last-seen/quality state. Decide whether a sensor can be assigned to one or several crop groups at a time. Require device proof-of-possession or an approved pairing process.
**Acceptance:** one farmer can retrieve only their own crop/sensor records; cross-account requests fail; sensors can be linked/unlinked and assigned with audit history; offline values have a trustworthy last-seen timestamp and are returned as stale.
**Evidence:** ER diagram/migration, endpoint contract, account-isolation tests, link/revoke walkthrough and online/offline fixtures. Do not seed Figma example profile/phone as real user data.

## 5. Front-end work plan

### FE-0 — Confirm active client and baseline

Confirm top-level lib/ and backend/public/ are the active clients; identify stale nested copies and map screens/components.
**Acceptance:** screen inventory matches running branch.
**Evidence:** source paths, current build/run result if performed, annotated screenshots.

### FE-1 — Product truth and accessible status

Make simulation/source banner visible on overview and trends; show crop limits and units; show measurement time separately from last successful refresh; use text/icon/color for state; replace static “synced” claim with measured age or remove; identify synthetic baseline.
**Acceptance:** user can identify simulated data and timestamp; offline/stale never looks green/in-range.
**Evidence:** overview/trend/offline screenshots and accessibility checklist.

### FE-2 — Main-screen states

Complete Overview, Trends, Alerts and Settings states: loading, empty, API error, connected, breach, stale/offline and retry. Align web/mobile wording and keep forecasts out of scope.
**Acceptance:** each state is understandable and does not fabricate a value/status.
**Evidence:** state capture set and scenario results.

### FE-3 — Crop and threshold interactions

Improve selector and Add Crop dialog; explain limits are illustrative/source-review pending; validate input and min/max; prevent stale old-crop data appearing current.
**Acceptance:** successful crop change updates crop/limits/reading consistently; failure preserves prior view.
**Evidence:** before/after API/screen and invalid/duplicate submissions.

### FE-4 — Alert and demo behavior

Show triggering values, exceeded bound, source/time, acknowledgment state and “dispatch logged, not sent”; gate demo breach by demo mode; confirm only after server response.
**Acceptance:** user distinguishes threshold event from spoilage and simulated log from delivery.
**Evidence:** matched alert/API/SMS log and demo screenshots.

### FE-5 — Connection and export behavior

Validate backend address, show actual connection result/last refresh, explain recovery; clarify export fields/provenance and sharing feedback; omit secrets/unneeded personal data.
**Acceptance:** wrong address/outage recoverable; exports contain expected fields/source.
**Evidence:** settings/offline/recovery captures and redacted samples.

### FE-6 — Login/auth UI decision

If server auth is out of scope, label entry as Demo profile and say credentials are not verified. If in scope, connect to server auth, secure token storage, expiry/logout and errors.
**Acceptance:** UI language reflects actual security behavior.
**Evidence:** code path and walkthrough; auth tests only if implemented.

### FE-7 — Responsive/accessibility refinement

Check phone and desktop widths, font scaling, contrast, touch targets, semantic labels, focus order, keyboard navigation and chart alternatives.
**Acceptance:** critical paths work at agreed viewports; issues are fixed or disclosed.
**Evidence:** viewport screenshots/checklist; human testing only with approvals.

### FE-8 — Figma phone login and OTP screens (local demo UI implemented)

**Current increment:** Flutter and web now include Botswana phone-number entry, a local six-digit PIN screen, demo-profile creation and explicit disclosures. Web additionally gates the dashboard behind a browser-local demo profile and provides Accounts/My Crops views with static grouped sensor fixtures, search and filters. Sample digits continue locally; no OTP backend or SMS is called. The monitor API still has no authenticated session.
**Remaining work:** decide whether to implement BE-7; then add real loading/invalid/expired/rate-limit states and accessible one-time-code paste/autofill behavior if approved. Never present the sample PIN as verification.
**Evidence:** code in `lib/main.dart`, analyzer result, and a screenshot/walkthrough on the target device still needed. Do not report real authentication.

### FE-9 — Accounts and My Crops screens (demo UI implemented)

**Current increment:** `lib/account_screens.dart` and `backend/public/index.html` provide Accounts and My Crops demo screens, profile/count cards, crop-grouped sensor rows, local search, All/Attention/Offline filters, last-known offline labels and link/edit preview notices. Web rows are fixed demo fixtures, not backend readings.
**Remaining work:** decide whether to implement BE-8; load account-scoped service data, add real empty/loading/error states, enforce tenant isolation, and replace static freshness with device heartbeat only if device integration is approved.
**Evidence:** code and analyzer result; target-device screenshots and interaction walkthrough remain to be captured. Keep all rows marked as demo; no live connectivity claim.

## 6. Integration and regression plan

For each backend contract change:

1. Run the agreed API/unit tests.
2. Start backend using documented command; inspect health/status, crop profiles, readings/history/trends and alerts.
3. Open web and Flutter clients against the same backend; verify crop switch and generated breach synchronize.
4. Stop/restart service and verify persistence per entity.
5. Export CSV and Markdown; inspect fields, provenance and privacy.
6. Save command output and screenshots with date/build hash; update test report and requirement traceability.

Do not say “all regression checks pass” unless they were run on the submitted revision and output retained. Keep synthetic fixtures separate from approved user/site records.

## 7. Schedule template

Fill dates and owners with the team; none are invented here.

| Milestone | Start | Finish | Owner(s) | Dependency | Exit evidence |
|---|---|---|---|---|---|
| Scope/proposal reconciliation | [date] | [date] | [name] | Approved proposal/supervisor | Signed objective and scope table |
| Figma account/OTP scope decision | [date] | [date] | [name] | Supervisor, ethics and SMS/resource decision | Approved implement/defer decision and updated requirement statuses |
| Current implementation baseline | [date] | [date] | [name] | Repository access | Route/schema/persistence inventory |
| PRD/TRD/flow review | [date] | [date] | [name] | Baseline | Reviewed requirements IDs |
| Backend validation/persistence | [date] | [date] | [name] | Schema decision | Test matrix and restart evidence |
| Frontend provenance/state handling | [date] | [date] | [name] | API contract | Screens for success/error/stale/simulation |
| Security containment/auth decision | [date] | [date] | [name] | Deployment boundary | Threat checklist and negative tests or explicit exclusion |
| Integration/regression | [date] | [date] | [name] | FE/BE increments | Run log and evidence bundle |
| Evaluation/expert walkthrough | [date] | [date] | [name] | Ethics approval if participants | Anonymized record or expert checklist |
| Report assembly/review | [date] | [date] | [name] | Evidence complete | Reviewed report and appendices |
| Demo rehearsal/submission | [date] | [date] | [name] | Final build | Demo checklist/build version |

## 8. Ownership plan

Assign one accountable owner per task and a reviewer. Fill actual names with the team.

| Workstream | Owner | Reviewer | Evidence |
|---|---|---|---|
| Product/objective traceability | [name] | [name/supervisor] | Approved proposal/objective matrix |
| Backend/schema/API | [name] | [peer] | DDL, route examples and test output |
| Flutter UI/UX | [name] | [peer] | Screens and walkthrough |
| Web dashboard | [name] | [peer] | Browser screenshots/responsive behavior |
| Security/privacy | [name] | [supervisor/reviewer] | Threat model, route matrix, approvals |
| Research evaluation | [name] | [supervisor] | Method, anonymized evidence and limits |
| Report/references | [name] | [team] | Consistent citations and evidence |

Record contribution with dated commits, logbook entries, meeting decisions and artifact evidence. Identify each member’s concrete work even for shared tasks.

## 9. Verification matrix for Interim Report 2

| Requirement | Scenario | Expected result | Evidence | Report section |
|---|---|---|---|---|
| Reading validation | Valid and malformed payloads | Valid accepted; invalid safe 4xx; no partial side effect | Requests/responses | §6 |
| Threshold rule | At min/max and just outside each bound | Equality in range if strict comparator remains; outside triggers | Test table/alert object | §6 |
| Crop selection | Known, unknown, duplicate | Known updates; invalid is rejected | API/UI | §6 |
| Persistence | Write each entity, restart and query | Durable entities persist; volatile identified/fixed | Before/after IDs/counts | §6, §7 |
| Provenance | Inspect seeded/current record | Source remains distinct in API/UI/export | JSON/screenshot/CSV | §5.3, §6 |
| Alert semantics | Trigger demo breach | Alert created; SMS status is logged/simulation only | API/log/screen | §5.3, §6 |
| Offline behavior | Stop and restart service | Clear unavailable state; recover without false-safe state | Screenshot/record | §6 |
| Export | Readings and activity export | Expected fields, safe text, no secrets/unneeded personal data | Redacted files | §5.3, §6 |
| Authorization | Anonymous/wrong-role writes | Denied if implemented; otherwise report open risk | HTTP status/log | §6, §8 |
| Usability | Approved scenario walkthrough | Outcomes and observations recorded without overgeneralization | Anonymized notes | §7 |
| Build/demo | Documented setup/build | Reproducible or exact blocker stated | Build log/artifact hash | §5/appendix |

## 10. Definition of done

A task is complete only when requirement/scope is reviewed; code/config is in agreed active project path; acceptance behavior is exercised; output/screenshot evidence is saved; limitations are recorded; traceability is updated; and another team member can explain implementation and claim boundary.

## 11. Priority and scope control

- **P0 — report correctness/demo truth:** reconcile approved objectives, identify runtime, correct persistence/auth/SMS/prediction claims and label synthetic data.
- **P1 — reliable evidence:** API/schema correctness, required persistence, restart check, repeatable tests and exports.
- **P2 — core UX:** connection/stale/error states, alert explanation and crop correctness.
- **P3 — security gate:** isolate demo immediately; implement auth/TLS if approved and feasible, otherwise document exclusion and contain.
- **P4 — optional future work:** physical hardware, GSM, field study, forecasting or multi-site only after scope/resources/ethics approval.

## 12. Change control

For each scope, database, API, threshold, technology or schedule change, record request, reason, objective impact, compatibility, risk, approval, owner, date and required evidence. Update this plan and IR2 challenges/remaining-work sections. Do not retroactively describe approved deviations as part of the original proposal.

| Date | Change | Reason | Impact | Approval/evidence |
|---|---|---|---|---|
| [date] | [change] | [reason] | [requirements/schedule/data/client] | [record] |

## 13. Open decisions

- Confirm exact proposal objectives and named case-study site.
- Decide whether alerts/incidents/dispatch attempts must persist for assessment.
- Confirm submitted branch/revision and reconcile older architecture/audit documentation.
- Confirm whether authentication is assessed or the app remains local demo.
- Confirm testing/evaluation access and ethics/consent requirements.
- Source/review threshold values and document commodity stage/storage conditions.
- Assign schedule owners and real dates, including supervisor reviews and deadlines.
- Confirm required APK/device evidence and availability.
