# Baseline audit and research traceability

**Review date:** 15 October 2026  
**Scope:** the top-level app and backend in this repository, on branch `v.0.0.0.0.01`. The nested `flutter_application_1/` copies and the untracked `from sasa/` folder are not the runtime selected by the top-level README.  
**Review method:** source and configuration inspection, repository inventory, API probes against the local demo server, and one attempted Flutter widget test. No physical hardware, external SMS service, database, or deployment was available.

## Executive finding

The branch contains a working **simulated presentation prototype**, not an end-to-end IoT storage system. It has a Node/Express API, responsive web dashboard, Flutter client, random simulated readings, a simulated sensor POST utility, in-memory threshold/alert/history/incident collections, a persistent append-only dashboard action log, and CSV/Markdown exports. It does not contain a SQLite database, ESP32 firmware, a Wokwi project, physical sensor integration, real SMS dispatch, authentication, or meaningful automated backend test suites.

This distinction is material to the report. A threshold breach means only that a reading crossed a configured numeric bound. It is not evidence of actual spoilage or a measured probability of spoilage. The dashboard's storage-time estimate is a fixed heuristic derived from distance from the midpoint of configured limits; it is not a shelf-life model.

## Repository baseline

| Area | Observed implementation | State |
|---|---|---|
| Backend/API | `backend/server.js`, Express on `0.0.0.0:3000`, open CORS, status/health, readings, trends, thresholds, alerts, incident logging, actions, and export routes | Implemented for demo; unauthenticated and HTTP only |
| Reading source | Server creates random readings every five seconds; `backend/simulate-sensor.js` can POST additional generated readings | Simulated; no physical device or Wokwi config found |
| Storage | Readings, active crop, thresholds, trend buckets, alerts, SMS log, incidents are process memory; `backend/data/actions.jsonl` is the separate action log | Partial persistence only; domain data clears on restart |
| Threshold rules | Hard-coded Maize 10–27 °C / 30–70% RH and Tomato 10–20 °C / 85–95% RH; any single out-of-range reading creates an alert | Code works; values are illustrative and unsupported as validated risk cutoffs |
| SMS | Breach adds an entry with status `logged` to an in-memory array | Simulated; no modem/provider request or delivery/failure callback |
| Web dashboard | Static HTML/JS from `backend/public/index.html`; polls API and displays readings, alerts, charts and exports | Implemented against demo API |
| Mobile app | Top-level Flutter app in `lib/`; five-second polling, crop selection, manual/demo actions and exports | Implemented; widget test currently blocked by local Flutter setup |
| Cybersecurity | No authentication/authorization, broad CORS, plain HTTP, server bound to all interfaces; user/source/details fields are client supplied | High-risk for deployment beyond an isolated demo network |
| Automated tests | One Flutter scaffold widget test; no backend test files or test script in `backend/package.json` | Insufficient coverage |
| Performance evidence | No recorded benchmark/test output found in the scoped repository | Not measured; do not state latency or throughput results |
| Hardware/cost | No hardware or supplier quotation evidence in this repo | Planned/estimated only |

`PROJECT_CONTEXT.md`, `BUILD_GUIDE_FOR_CURSOR_AI.md`, and `Final_Report_DRAFT.md` contain design plans and older architecture statements. They are not evidence that SQLite, Kotlin, six crops, cooldown logic, firmware, Wokwi, or real SMS exist in the top-level implementation. The final report's objective wording and cost table below are transcribed from its draft and still need reconciliation with the approved proposal and source documents.

## Research objective-to-code traceability

The objective text below is copied from the untracked `Final_Report_DRAFT.md` in this checkout, not verified against the approved proposal.

| Draft objective | Relevant implementation/evidence | Audit assessment |
|---|---|---|
| 1. Investigate current post-harvest practices and loss patterns through consultation | No consultation records, participant data, or loss dataset are part of the runtime repository | **Unverified / no evidence in code repo**; establish from approved research records, not software claims |
| 2. Identify cost, connectivity, and power constraints | `README.md` documents local-network operation; report draft contains an estimate table, but no dated supplier quotations are provided here | **Partially addressed in design**; cost and user/context findings remain unverified |
| 3. Design sensor architecture and alert logic linking conditions to configurable thresholds | Hard-coded two-crop map; POST validation; per-reading comparisons; status/alerts/trend API; chart and mobile UI | **Partially implemented in simulation**; not configurable at runtime/admin level; limits not validated; no sensor hardware |
| 4. Develop a functional prototype comprising IoT sensor hardware and SMS/mobile alert | Dashboard, Flutter client and sensor simulator exist; threshold alerts display in app/web; SMS only logged in memory | **Partially implemented as software demo**; hardware and SMS requirements are unmet |
| 5. Pilot at a storage site and assess accuracy, usability, impact | No field data, calibration dataset, participant evaluation, or pilot evidence in this repository | **Unverified / not demonstrated** |

## Crop limits: source check and interpretation

The software's current values are Maize **10–27 °C and 30–70% RH**, and Tomato **10–20 °C and 85–95% RH**. The `BUILD_GUIDE_FOR_CURSOR_AI.md` itself calls its thresholds illustrative. The code does not cite a source, distinguish produce maturity/stage, measure grain moisture, or encode duration of exposure.

- **Tomato:** UC Davis Postharvest Research and Extension Center describes stage-dependent storage temperatures (mature green 12.5–15 °C, light red 10–12.5 °C, firm ripe 7–10 °C for a few days) and optimum RH 90–95%. Its ripening conditions are different again. FAO guidance gives 12.5–13 °C and 85–90% RH for tomato storage. Thus the code's broad 10–20 °C / 85–95% envelope spans differing contexts; it is not a single validated cutoff. See [UC Davis tomato postharvest factsheet](https://postharvest.ucdavis.edu/produce-facts-sheets/tomato) and [FAO optimum storage conditions table](https://www.fao.org/4/y4358e/y4358e08.htm).
- **Maize grain:** FAO guidance emphasizes drying grain to safe moisture content (roughly 12–14% depending on temperature/source) and the interaction of grain moisture, temperature, storage time, and aeration. It does not support the code's exact 10–27 °C / 30–70% ambient RH alert box as a spoilage classifier. Grain moisture content and internal grain conditions are absent from this system. See [FAO post-harvest maize technology](https://www.fao.org/4/t0395e/T0395E04.htm), [FAO maize mould-control guidance](https://www.fao.org/4/x5036e/x5036E1d.htm), and [FAO maize marketing and storage](https://www.fao.org/4/x0530e/x0530e05.htm).

**Required report treatment:** call the implemented numbers *illustrative demo thresholds* pending a supervisor-approved, commodity/stage-specific evidence table. Do not claim that crossing them confirms spoilage, predicts remaining storage days, detects aflatoxin, or measures prevented losses.

## Prioritised gaps and incremental plan

1. **Correct report claims (before more implementation):** reconcile the report to the code and attached evidence. Remove or mark as planned/unverified claims for SQLite, six commodities, firmware/Wokwi, cooldowns, sent SMS, persistence, benchmarks and field outcomes. Freeze the approved objectives and cite each crop/stage threshold.
2. **Safety of the demo:** label synthetic data, heuristic shelf-time and logged-not-sent alerts in both interfaces. The backend currently presents a 5-minute sync label regardless of actual sync time; replace with measured age or remove it before any user evaluation.
3. **Data integrity:** design and approve a small SQLite persistence increment for readings, threshold config, alerts and incidents; preserve API response contracts and add restart/recovery tests. Keep trend synthetic data explicitly distinguishable from sensor observations.
4. **Verification:** add backend tests for boundary values, stale data, alert/ack flow, restart persistence, malformed/oversized requests, export escaping and rate/failure cases. Add a Flutter widget test that matches the current Peo Yame UI. Record actual output; benchmark only with a repeatable harness.
5. **Security:** define deployment boundary and threat model. Before LAN or field deployment, add device/client authentication, authorization for state-changing routes, restrictive CORS, request limits, secret/config handling and transport protection; verify these with negative tests.
6. **Hardware/SMS/pilot (separate approvals and evidence):** integrate calibrated sensor hardware, then real SMS transport with failure/delivery recording, then conduct the approved field pilot and collect accuracy/usability/outcome evidence. Do not infer these results from simulator output.

## Claims supported here vs unverified

**Supported by inspected code/API probes:** the demo exposes the documented current API; accepts valid numeric readings and rejects selected malformed values; supports Maize/Tomato selection; flags a tested out-of-range reading and creates an alert; writes an in-memory simulated SMS-log entry; provides synthetic trend baseline and CSV output; the server synthesizes readings.

**Still unverified or unsupported:** physical sensor accuracy; hardware integration; real SMS transmission/delivery/failure handling; persistent domain data; stale-reading detection; API access control; field usability and spoilage reduction; all six-crop claims; validated shelf-life estimation; a named pilot/site; cost quotations or purchased BOM; performance/latency metrics; approved-proposal alignment. See `TEST_REPORT.md` for actual checks and limitations.

## BOM and cost assumptions

The draft report sums its listed component lines to **P845**; adding 25% procurement/logistics contingency gives **P1,056** after rounding. It then estimates **P1,400–P1,600 installed**, a further P344–P544 above the landed estimate, without a visible labour/install breakdown. The draft also says no hardware was purchased, but supplier names, quotation dates, shipping/tax basis, exchange-rate basis and evidence are TODO/missing. Arithmetic is internally consistent to rounding; market validity and installed-cost support are **unverified**. Treat all figures as planning estimates, not measured project results, until dated supplier evidence is appended.
