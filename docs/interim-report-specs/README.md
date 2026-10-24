# Peo Yame Interim Report Specification Pack

This folder contains six detailed Markdown documents to support product, design, technical implementation and evidence planning for the Peo Yame C7-RCP-23 capstone.

## Documents

1. [Product Requirements Document](01-product-requirements-document.md) — problem framing, goals, scope, personas, functional/non-functional requirements, acceptance criteria and report traceability.
2. [Technical Requirements Document](02-technical-requirements-document.md) — observed architecture, stack, API contracts, technical requirements and operating constraints.
3. [App Flow and User Flows](03-app-flow-and-user-flows.md) — information architecture, user journeys, failure flows and evaluation scenarios.
4. [UI/UX Design Brief](04-ui-ux-design-brief.md) — design intent, observed tokens, components, screen specs, copy rules and accessibility/evaluation checklist.
5. [Backend Schema, Security Design and Threat Model](05-backend-schema-security-and-threat-model.md) — current SQLite schema, proposed target data model, authentication/security boundary, threats and checklist.
6. [Implementation Plan](06-implementation-plan.md) — staged frontend/backend work, integration evidence, schedule/ownership templates and report verification matrix.

## How to use this pack for the interim reports

- Use the PRD/TRD and flows as design requirements and artefact-design support for Interim Report 2.
- Use screen specifications and schema/threat model as labelled figures/tables or appendices; adapt to the department template.
- Use the implementation plan to update the Gantt chart, owner allocation, remaining work and evaluation evidence.
- Replace bracketed placeholders with team-approved facts; reconcile objectives/title/site with the approved proposal and supervisor.
- For section 5.3, attach dated screenshots, API examples, schema/ER diagram, logs, export samples and test results from the exact build submitted.
- Mark each item implemented, partially implemented, planned, unverified or out of scope based on evidence.

## Source and claim boundary

These documents use the supplied C7-RCP-23 Interim Report student guide, project context notes, top-level Flutter/Express source, repository README/audit material, the provided [Figma mobile-app design](https://www.figma.com/design/xc2ErOTLftSvxz2ZlVQHcU/Peo-Yame-%E2%80%94-Storage-Monitor-Mobile-App?node-id=0-1) and the user-provided [Figma AI added-screen screenshot](figma-ai-added-screens-2026-10-24.png). Flutter and web artifacts now include local demo UI for phone/OTP, Accounts and My Crops. The web dashboard also removes unvalidated crop-quality and storage-duration estimates. The screenshot explicitly says authentication, SMS and live sensor connections are not implemented; the new UI does not add those backend services. Current code was treated as authoritative when older notes conflicted. Some older audit/architecture documents may be stale: current backend/database.js creates SQLite tables for crops, app_settings and readings, while alerts, SMS log and incidents in backend/server.js remain in memory; action history uses JSONL. The OTP flow is not server-authenticated, and the sensor/account rows are local sample data. No physical sensor calibration, actual SMS delivery or field pilot is established by these specifications.

These are planning and reporting artifacts. A requirement, security control, test plan or target schema is not proof it has been implemented or verified. Attach evidence from the submitted revision and describe limitations honestly.
