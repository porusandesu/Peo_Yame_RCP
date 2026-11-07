# Peo Yame Interim Report Specification Pack

> **Current build status (2026-11-07, `pauls-branch`):** The Flutter and web clients open directly into session-free Demo mode as Mr Lesego Lefoko (`LLefoko@email.co.bw`). They do not currently show phone login or OTP screens. Phone-number account login and backend-backed, bidirectional QR single sign-on are requested future work, not implemented functionality. References below to interactive OTP/demo-profile screens describe an earlier revision or Figma design intent. The current crop package and CI evidence are documented in [the handoff](../HANDOFF.md), [crop package](../BOTSWANA_CROP_STORAGE_PACKAGE.md), and [verification record](../TEST_REPORT.md).

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

These documents use the supplied C7-RCP-23 Interim Report student guide, project context notes, top-level Flutter/Express source, repository README/audit material, the provided [Figma mobile-app design](https://www.figma.com/design/xc2ErOTLftSvxz2ZlVQHcU/Peo-Yame-%E2%80%94-Storage-Monitor-Mobile-App?node-id=0-1) and the user-provided [Figma AI added-screen screenshot](figma-ai-added-screens-2026-10-24.png). The phone/OTP screens described in the design sections are historical UI or target design intent; they are not present in the current demo. Both clients now offer direct session-free demo entry. Current backend/database.js creates SQLite tables for crops, app_settings and readings, while alerts, SMS log and incidents in backend/server.js remain in memory; action history uses JSONL. There is no phone-authentication or QR SSO service. The sensor/account rows are local sample data. No physical sensor calibration, actual SMS delivery or field pilot is established by these specifications.

These are planning and reporting artifacts. A requirement, security control, test plan or target schema is not proof it has been implemented or verified. Attach evidence from the submitted revision and describe limitations honestly.
