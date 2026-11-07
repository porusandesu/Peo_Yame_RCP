# Interim Report 1 and 2 correction plan

**Purpose:** Give the team a concrete, evidence-led plan for correcting the
combined interim report in
`/home/porusandesu/Downloads/Peo_Yame_Interim_Reports_1_and_2.docx`.

**Review basis:** The report is dated 6 November 2026. The repository has moved
on since then. Its 6 November screenshots and 19 October test run must remain
identified as historical evidence. Current implementation claims should be
checked against the current `pauls-branch` build and its CI evidence before
submission.

## 1. Correct the central account of the product

The report should explicitly describe the current product as **two clients
with unequal feature coverage**. The mobile app currently exposes more
farmer-facing functionality than the web client, particularly mobile QR
scanning/approval, authenticated crop-site management, sensor linking and
unlinking, and profile actions. The web client has account and QR flows, but
the two clients have not had a complete end-to-end parity and synchronization
evaluation.

Do not write that “the apps do not sync” as an established technical fact. The
current implementation uses one backend, server-sent update events (SSE), and
a mobile polling fallback; CI has assertions for matching updates to two
clients. At the same time, those checks do not prove every screen in both
clients refreshes correctly in a real browser and phone session. Report this
as **shared-backend synchronization implemented and partly tested; full
cross-client interaction and parity not yet demonstrated**. This reconciles
the architecture/test evidence with the observed product gap.

## 2. Make the report’s time boundary explicit

Add a short “Evidence cut-off and build identification” box near the start of
Part B with:

- report screenshot capture date and the build/commit they show, if known;
- the historical test date and commit (`19 October 2026`, `74d7250`);
- the current source commit and the CI run used for current implementation
  evidence;
- which observations are screenshots, which results are automated tests,
  and which are still unverified.

The latest recorded CI evidence in the repository is run
`42395495226` (check its commit and job results before citing it). The
`docs/TEST_REPORT.md` entry for run `42394803726` records backend checks on
Linux and Windows, Flutter tests/analysis, Android APK build/upload, and
Windows package smoke-test/upload. CI does not prove physical-camera use,
real sensor connectivity, SMS delivery, visual quality on a device, or
complete web/mobile authentication journeys. Cite run links and exact claims;
do not label CI as a full product acceptance test.

## 3. Reconcile specific stale or incorrect statements

Update these items throughout the executive summary, requirements, feature
tables, defect list, evaluation, and remaining-work plan. Preserve their
historical context where relevant.

| Report statement or finding | Required correction |
|---|---|
| Mobile has six destinations, with Accounts as a tab | Current mobile navigation has five destinations: Overview, Trends, My Crops, Alerts, Settings. Accounts is reached separately. Update the feature inventory and screenshots/captions. |
| Demo uses phone-and-PIN sign-in, or a demo PIN verifies identity | Demo is direct, shared, session-free entry. Farmer sign-in uses phone and password; optional authenticator/TOTP is supported. Never describe a demo PIN as identity verification. |
| D1: mobile estimates crop quality, degradation risk, or storage days | This describes the 6 November screenshot. Current UI removed these unsupported estimates. Mark as a historical defect, record the corrected build and evidence, and retain the limitation that target bands are indicative rather than validated spoilage predictions. |
| D2: My Crops summary conflicts with a fixed sample list | The current app removed the hard-coded account summary and uses backend-owned locations/sensor associations. Mark the old screenshot defect historical; cite current automated coverage, and separately note the lack of a full browser/phone acceptance run. |
| D3: app says “Safe” | Current UI uses range-based wording such as “In range.” Mark the old wording as fixed only after confirming current web, mobile, and export text. Explain that “in range” means within configured limits, not safe for consumption or free of spoilage. |
| D4/T-12: “verified by one-time PIN” / demo PIN flow | Correct to the supported phone/password account flow with optional TOTP and backend-mediated QR SSO. State that SMS OTP is not provided. Do not imply real-world identity verification. |
| “Six destinations” / account page shown as a tab | Use current five-tab layout and describe Accounts as a separate destination/action. |
| D5–D9 all remain open | Recheck each against the current UI and current source. Preserve the original screenshot observation, then give status: open, fixed with evidence, or not reproduced. Do not carry an old screenshot issue forward as a current defect without checking. |
| Mobile and web use “the same data at the same time” | Qualify: both use the shared backend and update stream; automated shared-event assertions pass, with mobile polling fallback. Full page-level parity, browser/mobile live-session behavior, reconnect freshness, and all mutations have not been proven end to end. |
| Global demo data and farmer data are interchangeable | Separate shared synthetic Demo readings/catalog/alerts from authenticated farmer-owned account, site and sensor-association data. State which screens read each data domain. Do not label fixtures or synthetic readings live or farmer-owned. |

If an item cannot be confirmed from current code/tests, label it “not
verified” and put it in remaining work; do not infer a pass from the existence
of a screen or API endpoint.

## 4. Add a web/mobile parity and synchronization section

Add a table to Part B (and a short evaluation in B7) with one row per user
journey. Use columns: **Journey**, **Mobile**, **Web**, **shared data/API**,
**refresh mechanism**, **evidence/status**, **known gap**. At minimum cover:

1. Demo entry and shared profile.
2. Farmer registration, phone/password sign-in, session restore, sign-out.
3. Optional authenticator setup and sign-in (including unsupported client
   controls such as browser TOTP disable).
4. QR SSO in both directions, expiry and single-use behavior.
5. View/edit account profile.
6. Browse/select/add a crop in shared Demo.
7. Create/delete a farmer-owned crop/storage site.
8. Discover, link and unlink a sensor ID; clarify that discovery depends on an
   actual submitted reading and is not physical sensor provisioning.
9. Readings, active crop/threshold display, trends, alerts and alert
   acknowledgement.
10. Disconnect/reconnect, stale/offline state, retry and polling fallback.

For each row, use only these evidence labels, with a short explanation:

- **Automated test:** link the exact CI run and test assertion.
- **Manual observation:** name client/device/browser, date, account/data state,
  and steps performed.
- **Source inspection:** use only for implementation facts, not claims that a
  user journey works.
- **Not verified / not implemented:** state the gap plainly.

The parity discussion should say that mobile currently has richer farmer
management flows. Explain why that makes the experience asymmetric even
though both clients connect to the same backend. Do not claim feature parity
until equivalent supported journeys work in both clients or a deliberate,
documented reason explains why a feature is mobile-only.

## 5. Perform and record a focused synchronization check

Before claiming that both apps stay in sync, run a small scripted/manual
acceptance session with one backend instance and one test farmer account. Use
the web client and mobile client at the same time. Keep Demo and authenticated
farmer data clearly separate. Record actual timestamps, screenshots or a
screen recording, test-account state (redact credentials), build commit, and
outcome for each step:

1. Open both clients and confirm the same backend origin and correct identity
   state. Confirm Demo does not become a farmer session.
2. Change active Demo crop in one client; verify the other client updates and
   displays the same crop and target band.
3. Trigger a Demo breach; verify both clients show the same alert/reading
   values, then acknowledge it in one and observe the other.
4. Sign in as the same farmer where supported; edit the profile and verify the
   new server-confirmed value appears in both clients after the account update.
5. Create a farmer-owned storage site in mobile and verify it appears in web;
   link/unlink a sensor where a real submitted reading is available and verify
   both views refresh. If the web screen cannot perform or show an operation,
   record that as a parity gap, not as sync failure.
6. Disconnect one client/network briefly, make a change from the other, then
   reconnect. Check for retry, duplicate/stale data, accurate last-updated
   time, and eventual convergence. Never describe stale values as current.
7. Repeat key steps after a page/app restart and document which records persist
   and which reset.

If device access is unavailable, do not fabricate manual results. Cite the
existing simultaneous-client SSE integration assertions as **backend
event-level evidence only** and keep client-level synchronization marked
partly unverified.

## 6. Update missing academic and project-control information

Resolve the report’s own placeholders and caveats before submission:

- replace all student `[insert]` IDs and verify names, group, supervisor, and
  submission details;
- compare objectives and scope against the approved proposal and approved
  Interim Report 1; record approved changes with rationale, date, and
  supervisor sign-off;
- complete task owners and each member’s contribution evidence in B10/B11;
- confirm ethics/consent requirements with the supervisor/institution before
  any survey, interview, or site data collection; report what was approved and
  what was actually collected;
- reconcile requirements/specification tables with current implementation,
  especially accounts, QR SSO, farmer-owned sites/sensors, web/mobile scope,
  sync, and data persistence;
- finish the reference list: remove placeholders, verify author order, title,
  venue, date, URL/DOI and access date; support every crop range and
  agronomic statement with traceable page/table-level evidence;
- distinguish proposed plans from results. O1 primary research and O5
  physical accuracy/pilot remain unmet unless new evidence exists;
- add a compact risk/limitations entry for authentication/security, personally
  identifying phone numbers, shared Demo telemetry, stale data, and lack of
  real sensors/SMS. Avoid describing the prototype as production-ready.

## 7. Make the test and defect sections actionable

Replace the old undifferentiated test inventory with a dated matrix containing
**test ID, requirement, setup/build, steps/input, expected result, actual
result, evidence link, status, and limitation**. Separate:

- October historical tests (do not silently re-date or re-run their results);
- current automated CI/backend/mobile tests;
- manual cross-client acceptance checks;
- tests not run.

In the D1–D9 register, add **first observed build/date**, **current status**,
**fix commit/build**, and **verification evidence**. Keep a defect open if
there is only a code change but no relevant verification. For D8 and all
security statements, distinguish authenticated farmer-owned routes from
global Demo/API routes, and state that passing integration tests are not an
independent security audit.

Report limits still needing explicit evidence or resolution include physical
sensor accuracy/calibration and outage behavior; real SMS delivery; browser
and mobile end-to-end auth; camera scanning on a device; export escaping and
formula-injection behavior; persistence/restart semantics for alerts and
incidents; TOTP controls and failure handling; and stale/offline recovery.

## 8. Recommended edit order

1. Freeze the current source commit and collect its CI links/results.
2. Correct the executive summary and evidence cutoff so they describe the
   actual product and distinguish old from current evidence.
3. Reconcile requirements and implementation tables (B3–B5), adding the
   parity/synchronization matrix.
4. Run the focused cross-client acceptance session if devices are available;
   otherwise mark that evidence gap explicitly.
5. Rebuild B6 test matrix and D1–D9 disposition from dated evidence.
6. Recalculate B7 objective/requirement evaluation and B10 remaining-work
   schedule from those statuses.
7. Complete IDs, contribution records, ethics/scope approvals, references and
   figure captions.
8. Review the whole document for unsupported words such as “verified,”
   “safe,” “live,” “real-time,” “accurate,” “complete,” and “parity.” Each
   should point to evidence or be replaced with a bounded description.

## Suggested replacement summary paragraph

> The current prototype has web and mobile clients backed by a shared service.
> The clients share Demo and farmer-account data through backend APIs and
> update events, with automated evidence for selected backend and client
> behaviors. Mobile currently provides more complete farmer site and sensor
> management than web, so feature parity and full user-visible synchronization
> have not yet been demonstrated end to end. Demo readings are synthetic;
> physical sensor accuracy, SMS delivery, field performance, and validated
> spoilage prediction have not been established. Historical screenshot
> findings are reported separately from defects verified on the current
> build.

Use this paragraph only after checking that each implementation statement
still matches the build being submitted.
