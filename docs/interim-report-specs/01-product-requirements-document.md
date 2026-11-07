# Product Requirements Document (PRD)

> **Current runtime update (7 Nov 2026):** Demo mode opens directly without
> authentication; the historical login requirements below are not current demo
> behavior. Production auth and QR SSO remain available.

> **Historical planning snapshot (24 October 2026).** Its implementation-status passages predate the current account, email/password, persistent session and signed-in QR pairing work. Use the current [README](../../README.md), [architecture](../ARCHITECTURE.md), [test report](../TEST_REPORT.md) and [handoff](../HANDOFF.md) for implementation claims; retain this file for requirements history.

**Product:** Peo Yame — low-cost post-harvest storage monitoring prototype
**Project:** Development of a Low-Cost IoT-Based Post-Harvest Storage Monitoring and Spoilage-Risk Alert System for Small Agricultural Aggregators in Botswana
**Module:** C7-RCP-23 Research Capstone Project
**Document status:** Working product requirements baseline for interim reporting
**Prepared:** 24 October 2026
**Evidence basis:** Project context, top-level repository README, Flutter/Express source, project architecture and audit notes. Reconcile objectives and wording against the approved proposal and supervisor directions before submission.

> **Claim boundary:** Peo Yame in the current repository is a software prototype that demonstrates simulated readings, crop-bound comparisons, a web dashboard, a Flutter client, and local data handling. It is not connected to physical sensors and does not send real SMS. A threshold breach is not proof of spoilage, a validated risk probability, or loss prevention. Clearly mark verified behavior, simulated behavior, future scope, and unverified items in all reports.

> **Later implementation update (7 November 2026):** The backend now seeds a
> Botswana crop catalog for grains, pulses, oilseeds, vegetables and fruits.
> Web and mobile crop setup show the selected profile's storage guidance.
> These researched starter values are not validated operating thresholds. The
> low-literacy workflow in the [crop package](../BOTSWANA_CROP_STORAGE_PACKAGE.md)
> is a recommendation that needs farmer evaluation. Earlier implementation
> status text in this October planning snapshot is superseded by the current
> [handoff](../HANDOFF.md) and [architecture](../ARCHITECTURE.md).

## 1. Executive summary

Peo Yame is intended to help a small agricultural aggregator notice temperature and relative-humidity conditions outside selected crop limits in a storage setting. The project context prioritizes low cost, SMS-first alerting for weak-connectivity conditions, understandable presentation for non-technical staff, retained records, and future commodity extensibility. The capstone prototype uses simulated input so the team can develop and demonstrate the core information flow without claiming unavailable hardware.

The current artefact consists of a Node.js/Express service, a SQLite data layer for crop profiles/readings, a responsive browser dashboard, and a Flutter mobile client. The Flutter build now includes Figma-inspired phone-login/OTP demo screens and Accounts/My Crops screens with fixed sample profile/sensor fixtures. Those screens do not connect to authentication, SMS or a live sensor registry. The backend creates alerts and SMS-like log entries in process memory; a separate JSONL file retains dashboard actions. There is no implemented user authentication, real SMS provider, calibrated sensor, field pilot, or validated spoilage model.

## 2. Problem, opportunity and context

Small produce aggregators may lack affordable, timely visibility into storage conditions and may have limited connectivity or technical support. The approved research proposal should be the authority for the local problem statement, evidence of losses, site/case-study identity, objectives and claims. Do not treat this PRD as new research evidence. In the prototype, temperature and humidity values are provided by software simulation; no real storage environment is measured.

### Problem statement template for final report

> [Use the approved proposal’s exact problem framing. Identify the affected storage users, the documented monitoring/communication gap, the Botswana context and its evidence. Distinguish sourced/context findings from the team’s interpretation.]

### Product opportunity

Demonstrate a simple, low-cost monitoring workflow that can:

1. receive or simulate temperature and humidity observations;
2. associate observations with the selected crop profile and timestamp;
3. compare measurements against configured illustrative limits;
4. present current condition and history in plain language;
5. create a visible alert and record a simulated dispatch event; and
6. preserve sufficiently clear evidence for evaluation and future physical integration.

## 3. Product vision and goals

**Vision:** Make storage-condition monitoring understandable and demonstrable for small agricultural storage operations, with a future path toward low-cost sensing and SMS-first alerts.

### Product goals

- Demonstrate an end-to-end software path from synthetic reading to API, threshold rule, alert and client display.
- Present readings and alert context in a way a non-technical operator can understand.
- Demonstrate crop profile selection and thresholds without suggesting that the demo values are agronomically validated.
- Retain and export relevant prototype records to support interim-report evidence; report exact persistence boundaries.
- Keep the architecture simple enough for a capstone team to explain, operate locally and extend later.
- Provide a credible plan for security, hardware integration and evaluation without representing future work as implemented.

### Non-goals and explicit exclusions

- No physical sensor calibration or field hardware claim in the present prototype.
- No real GSM/SMS transmission or carrier delivery confirmation; current SMS status is logging/simulation only.
- No machine-learning prediction or validated shelf-life estimate. Any existing heuristic estimate must be labeled as a demo heuristic and excluded from operational claims. Confirm scope against approved proposal; project notes say predictive forecasting is out of scope.
- No claim that a reading proves spoilage, contamination, avoided loss, or causal impact.
- No multi-site deployment, cloud operation, public production release, or commercial service unless the proposal/supervisor explicitly revises scope.
- No production identity/account system in the current phone-login/OTP demo. The six-digit sample PIN advances a local demo profile; it is not verified by a server.
- Accounts and My Crops now have interactive Flutter screens, but profile totals, crop groups, sensor rows, freshness labels and filters are sample UI data, not records from authenticated farmer accounts or physical devices.

## 4. Users and stakeholders

Personas below are working design roles, not interview findings. Replace or validate them using approved research.

| Role | Needs | Risks / constraints | Current prototype support |
|---|---|---|---|
| Storage attendant / store operator | Read current condition quickly; understand what action is needed; see when data was recorded; acknowledge an alert | May have limited digital literacy, intermittent network or small phone screen; false reassurance from stale/synthetic data | Dashboard summary, crop selection, status, alert screen; actual stale-data behavior needs verification/improvement |
| Aggregator manager | Review history, incidents and alert activity; export evidence; understand current operating status | Needs reliable records and clear distinction between simulation and field data | Reading/trend display and exports; alert/incident retention boundaries must be documented |
| Project team / researcher | Demonstrate behavior, reproduce scenarios, gather evidence and explain limitations | Simulation bias, weak test coverage, evolving requirements | Simulator, demo-breach action, API, action log and exports |
| Supervisor / examiner | Assess traceability, method, implementation status, evidence and honest scope | Unsupported claims, proposal drift, undocumented decisions | Interim-report evidence package and requirement traceability are team responsibilities |
| Future maintainer / integrator | Understand API/data contracts and replace simulation with a sensor/SMS adapter | No current device identity, hardened auth or transport security | Simple service boundary; secure integration remains planned work |

## 5. Product scope

### Current demonstrator scope (verify against current branch at submission)

- Local Express API and static browser client.
- Flutter mobile dashboard client.
- Software-generated synthetic readings and optional simulator client.
- Maize and Tomato crop profiles with illustrative numeric limits; current repository source is authoritative for exact values.
- Status, history, trends, thresholds/crops, alert, incident, action and export routes as implemented.
- Alert created when a reading crosses at least one configured bound; a simulated SMS log is added with `logged` status.
- SQLite storage for crop definitions, app settings and readings in the current source; verify migrations/retention/restart behavior. Alerts and incident state are currently process-memory structures in the inspected server implementation. Action history is a separate JSONL file.

### Planned or future scope (not to be marked done without evidence)

- Real ESP32/DHT22 or equivalent device and calibration.
- Real GSM or SMS service, delivery outcomes, retries and offline queueing.
- Authenticated device/user accounts, role-based permissions and secure transport.
- Field/site pilot and reference-instrument, usability or impact evaluation.
- Evidence-based crop- and stage-specific thresholds reviewed by appropriate domain expertise.
- Durable alerts, incidents, audit events and configurable retention if not already implemented.

## 6. Functional requirements

Status meanings: **Implemented (source observed)** means behavior exists in inspected code; it is not necessarily validated as a complete user need. **Partial** means a demonstrator exists but requirement is incomplete. **Planned** means no current implementation claim. Confirm statuses with current commit and evidence before report submission.

| ID | Requirement | Priority | Status/evidence note | Acceptance condition for project evaluation |
|---|---|---:|---|---|
| FR-01 | The service shall accept numeric temperature and relative-humidity readings with a timestamp assigned by the service and source/context metadata. | Must | Partial; POST `/api/readings` exists; validation and stored fields inspectable | Valid payload is accepted; malformed numeric values and RH outside 0–100 are rejected; stored reading can be retrieved with timestamp/source |
| FR-02 | The service shall associate each reading with the active crop profile and site label. | Must | Partial; one active crop is global; site is a submitted string | Returned/stored record shows correct crop/site; a mismatched supplied crop is rejected with documented response |
| FR-03 | The system shall compare each reading with the active crop’s min/max temperature and humidity bounds. | Must | Implemented as simple comparison | Boundary and out-of-range scenarios produce expected breach boolean; test report makes no spoilage inference |
| FR-04 | The system shall present the latest reading, selected crop/limits and overall condition. | Must | Implemented in clients/API | Client displays values, units, timestamp/source and status; missing/error state is explicit |
| FR-05 | The system shall maintain a reading history and show a trend view for selectable periods. | Should | Partial; current trend may combine seeded synthetic history and live readings | Range selection changes returned/displayed series; synthetic points are visibly distinguished; no forecast appears |
| FR-06 | On configured bound breach, the system shall create an alert linked to the triggering reading and show it to the operator. | Must | Implemented in runtime logic; alert storage currently in-memory | Known breach produces alert with crop, reading, limits, time and acknowledgement state; restart limitation is recorded |
| FR-07 | The system shall record simulated SMS dispatch intent/status without claiming carrier delivery. | Must for demo | Partial; `status: logged` in memory; no gateway | Breach creates a log entry explicitly labeled simulated/not sent; documentation and UI avoid “delivered” language |
| FR-08 | The user shall be able to acknowledge a visible alert. | Should | Route exists; verify UI behavior | Acknowledgement state changes and is visible; unknown IDs return not found |
| FR-09 | The user shall select a saved crop profile and see its limits. | Must | Implemented for seeded grains, pulses, oilseeds, vegetables and fruit; global monitor selection is not farmer/site scoped | Selection updates active threshold and clients; values match API; limits labeled illustrative |
| FR-10 | An authorized administrator shall be able to create a crop profile with valid bounds. | Could / confirm scope | API route exists without auth; unsafe for deployment | Valid limits save; invalid/duplicate names and invalid ranges receive safe errors; unauthorized request denied after auth scope implemented |
| FR-11 | The user shall export readings and activity evidence. | Should | CSV and Markdown routes exist | Export opens with expected fields; sensitive data excluded; CSV formula handling and escaping reviewed |
| FR-12 | The client shall explain connection/loading/error states. | Must | Partial; API error handling exists; verify visual states | Offline/backend unavailable state is distinct from a safe reading; retry path is clear |
| FR-13 | The demo shall distinguish synthetic history and generated readings from actual sensor measurements. | Must | Partial; source metadata exists; UI labels must be checked | User can identify simulated data before acting; exports preserve source label |
| FR-14 | The project shall retain required research evidence through restart. | Must for final research evidence | Partial; readings/crops/settings use SQLite, alert/incident memory limitation | Restart procedure demonstrates exactly which record classes persist; any non-persistent classes are reported or made durable |
| FR-15 | The system shall authenticate users and sensor devices before protected operations. | Future security requirement | Not implemented; login is visual/client-only | Protected routes deny anonymous requests; credentials are not stored in plaintext; identity and role are enforced server-side |
| FR-16 | The sign-in flow shall accept a farmer’s registered Botswana phone number and request a one-time PIN. | UI demo implemented; backend planned | Phone form navigates to a local OTP screen; no OTP endpoint/provider and no SMS is sent | Current UI acceptance: phone entry reaches OTP mock and demo disclosure is visible. Target: registered number starts an expiring, rate-limited challenge |
| FR-17 | The OTP flow shall verify a six-digit PIN and support safe resend/change-number paths. | UI demo implemented; real verification planned | Six fields are prefilled with a sample PIN; any six digits advance locally; resend is a notice only | Current UI acceptance: edit PIN, change number, back and resend notice work. Target: server rejects incorrect/expired/reused PIN, applies limits, and never logs PIN |
| FR-18 | An authenticated farmer shall be able to view their account and linked crop/sensor totals. | UI mock implemented; account service planned | Accounts page renders demo profile and example counts; no authenticated ownership model exists | Current UI acceptance: account page opens and sign-out returns to demo login. Target: counts derive from authorized records and session revokes on sign-out |
| FR-19 | A farmer shall browse crops grouped with assigned sensors, including search and All/Attention/Offline filters. | UI mock implemented; data/API planned | My Crops groups four static sensor fixtures under Maize/Sorghum; search and filters operate locally; backend still uses one global crop | Current UI acceptance: groups/search/filters render demo fixtures and disclose simulation. Target: account-scoped real device values and actual freshness |
| FR-20 | An authorized farmer/operator shall link another sensor to their account and assign it to a crop. | Visual action implemented; pairing planned | Link/Add actions show a “not connected” demo notice; no registry/pairing exists | Target: authenticated proof-of-possession, owner authorization, duplicate/revoked-device rejection and audit trail |

## 7. Non-functional requirements

These are target requirements for design/evaluation. Do not imply they have been measured unless a result is attached.

| ID | Quality | Requirement / measure | Current limitation |
|---|---|---|---|
| NFR-01 | Cost | Prototype should run with no paid cloud service or subscription dependency | Does not establish eventual hardware, deployment or support cost |
| NFR-02 | Usability | Critical status and alert meaning should be understandable without interpreting charts alone; status must use text/icon as well as colour | User usability not yet evidenced by an approved study |
| NFR-03 | Reliability | Backend should recover after restart and retain the agreed research data set | SQLite currently covers crop/settings/readings; alerts/incidents are volatile in inspected code |
| NFR-04 | Data integrity | Sensor records must have validated values, source, crop/site and UTC timestamp; writes should not silently appear successful when persistence fails | Temperature plausibility bound, device authentication and full transactional coverage need review |
| NFR-05 | Connectivity | SMS-first behavior is a design requirement for limited-connectivity settings | Current prototype requires client/API network and does not deliver SMS or queue events offline |
| NFR-06 | Performance | Define and measure reading-to-alert processing and client refresh latency using a repeatable method | No accepted baseline/benchmark currently established; do not invent numbers |
| NFR-07 | Security | Restrict state-changing operations, minimize exposed data, use secure transport and verify input handling before non-isolated deployment | Current backend lacks authentication and uses demo HTTP/network settings |
| NFR-08 | Maintainability | Keep API/data logic separated from presentation and document decisions/configuration | Current service and UI have some separation; review code structure before claiming quality |
| NFR-09 | Accessibility | Support readable contrast, scalable text, large tap targets, semantic controls and non-colour status cues | Verify current screens and assistive technology behavior |
| NFR-10 | Extensibility | Commodity profiles should be data-driven; later device/dispatch adapters should not require UI rewrite | Crop profile insertion exists; device/SMS adapters are not integrated |
| NFR-11 | Transparency | Identify synthetic, live, stale, estimated, logged and delivered data distinctly | Synthetic metadata exists; some fixed/heuristic interface labels require audit |
| NFR-12 | Authentication safety | OTPs, if implemented, must be short-lived, single-use, rate-limited and never logged or returned in production responses | No OTP service exists; screenshot’s sample PIN is a design-only demonstration |
| NFR-13 | Tenant/account isolation | A farmer can access only their account’s crops, sensors, readings, alerts and exports | Current single-global-crop demo has no authenticated ownership boundary |
| NFR-14 | Sensor freshness | A sensor row must show last-seen time; offline values must be identified as historical and must not imply current conditions | Current simulator does not establish per-device heartbeat or offline state |

## 8. Data and business rules

- Temperature is represented in degrees Celsius; relative humidity is percentage RH.
- RH input must be finite and within 0–100. A physically plausible temperature range should be agreed and validated rather than assumed.
- Each reading is linked to one currently active crop profile in the present one-bay demo model.
- Breach means any temperature or humidity value is below the configured minimum or above the configured maximum. State explicitly whether exact boundary values pass (current comparisons use strict `<`/`>` so equality is in range).
- A single threshold crossing raises a demo event. It does not account for exposure duration, rate of change, sensor calibration, air-vs-produce temperature, grain moisture, maturity stage or a validated spoilage model.
- Current Maize/Tomato limits are demonstration settings. Source them and review them before treating them as operational thresholds.
- Service timestamps should be UTC ISO-8601; confirm consistency across DB, APIs, charts and exports.
- Synthetic seeded history must remain distinguishable from generated/live source data.

## 9. UX principles

1. Show the current condition and the reason for it before secondary analytics.
2. Never rely on colour alone; pair status color with words and icon.
3. State when data is simulated, stale, unavailable or heuristic.
4. Show the measurement time and units, not just a value.
5. Present an alert with the observed value, applicable limit, time and next action.
6. Keep routine operation accessible on a small Android screen and with low technical familiarity.
7. Treat any “logged” SMS as a record of application logic, never as a sent/delivered message.

## 10. Assumptions, dependencies and decisions

| Item | Current assumption/decision | Validation needed |
|---|---|---|
| Site model | Single site / one active harvest is the demonstrator scope | Confirm approved proposal and case-study site |
| Data source | Software simulation is the primary source until physical hardware is available | Team to preserve simulator evidence and label it accurately |
| Client platforms | Browser dashboard and Flutter mobile app | Confirm final report expects Android APK or web-only demonstration |
| Thresholds | Two built-in example profiles are illustrative | Cite sources and obtain appropriate review; do not claim six crops if unsupported |
| Persistence | Current SQLite code stores crops/settings/readings; other runtime entities may be memory-only | Execute and record restart checks before claims |
| Authentication | UI login is demo only | Decide whether auth is in scope; if not, record as security limitation and isolate demo |
| SMS | Dispatch logic is simulated | Hardware/provider access and real-send approval are future dependencies |

## 11. Risks and mitigations

| Risk | Impact | Mitigation / report treatment |
|---|---|---|
| Simulated readings mistaken for sensor observations | Invalid evaluation and misleading claims | Persistent simulation banners, source labels, synthetic-data caption; explain validity limits |
| Thresholds not suitable for crop/storage stage | False alerts or false reassurance | Source values, state crop stage/assumptions, supervisor/domain review; call demo limits illustrative |
| Backend volatile alert/incident state | Lost evidence after restart | Confirm persistence per entity, add durable store if within scope, export test evidence |
| No authentication on mutable endpoints | Unauthorized crop/alert/action changes on shared network | Keep service isolated; implement server-side controls before deployment; include threat model |
| No real SMS/network degradation test | Cannot assess SMS-first objective | Describe dispatch-level simulation; list real GSM and outage/retry testing as future work |
| Objective/site mismatch | Weak interim-report alignment | Reconcile with approved proposal; record approved deviations and site status explicitly |
| Schedule/resource access delays | Incomplete artefact or evaluation | Track owners/dependencies, schedule reviews and fallback simulation evaluation |

## 12. Requirement traceability for Interim Report 2

| PRD area | Report evidence destination |
|---|---|
| Problem, users, scope, goals | IR2 §1 and §3 |
| Functional/non-functional requirements | IR2 §3 requirements/specifications |
| Architecture/data boundaries | IR2 §4 artefact design |
| Actual technologies and build state | IR2 §5.1–5.2 |
| Screens, API, database and simulation evidence | IR2 §5.3 and appendices |
| Testable acceptance criteria/results | IR2 §6 |
| Objective achievement and limitations | IR2 §7–§9 |
| Team ownership and evidence | IR2 §10 and contribution logs |

## 13. Approval and change log

| Version | Date | Change | Owner/approval |
|---|---|---|---|
| 0.1 | 24 Oct 2026 | Initial report-oriented baseline compiled from repository evidence and project context | Team review and supervisor confirmation pending |

**Open decisions:** confirm official title/problem/objectives, named case-study site, final deployment boundary, user roles, privacy/ethics approvals, acceptable threshold sources, persistence expectations, whether authentication is in current build scope, and IR2 completion expectations.
