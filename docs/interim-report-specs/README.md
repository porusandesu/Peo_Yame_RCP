# Peo Yame Interim Report Specification Pack

> **Current runtime update (7 Nov 2026):** Demo authentication was removed in
> the current worktree. Web and mobile open the shared Demo Farmer directly;
> demo verification and sign-in endpoints are disabled. Production auth and
> QR SSO remain available. The dated flow and screen descriptions below are
> historical requirements and should not be presented as current demo flows.

> **Snapshot notice (7 Nov 2026):** These specifications were drafted from an
> October prototype and retain historical flow/schema descriptions. The live
> application now has SQLite-backed farmer accounts and assignments,
> email/password web sign-in, demo-only phone-verification skip (historical), authenticated
> one-use QR pairing in both web-to-mobile and phone-to-web directions, and a five-tab Flutter navigation with My
> Crops centered. Use the repository [README](../../README.md),
> [architecture](../ARCHITECTURE.md), [handoff](../HANDOFF.md), and
> [test report](../TEST_REPORT.md) for current runtime behavior. The backend
> now also seeds a Botswana crop catalog for grains, pulses, oilseeds, fruits
> and vegetables, with storage guidance; its sources and current verification
> boundary are in [the crop package](../BOTSWANA_CROP_STORAGE_PACKAGE.md).
> That document includes a proposed low-literacy farmer workflow, not a
> field-tested result. The documents
> in this folder are planning/reporting artifacts, not a current user guide.

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

These documents use the supplied C7-RCP-23 Interim Report student guide, project context notes, top-level Flutter/Express source, repository README/audit material, the provided [Figma mobile-app design](https://www.figma.com/design/xc2ErOTLftSvxz2ZlVQHcU/Peo-Yame-%E2%80%94-Storage-Monitor-Mobile-App?node-id=0-1) and the user-provided [Figma AI added-screen screenshot](figma-ai-added-screens-2026-10-24.png). Older implementation statements in this pack are historical. Current crop profiles are stored in SQLite and seeded with crop group, room ranges and storage notes; see the linked Botswana package. Farmer authentication and crop assignments are backend-backed, but sensor assignment is metadata and the readings remain synthetic unless a device submits them. No physical sensor calibration, actual SMS delivery, field usability study or validated spoilage model is established by these specifications.

These are planning and reporting artifacts. A requirement, security control, test plan or target schema is not proof it has been implemented or verified. Attach evidence from the submitted revision and describe limitations honestly.
