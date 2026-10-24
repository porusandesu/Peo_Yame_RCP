# Backend Schema, Security Design and Threat Model

**System:** Peo Yame low-cost storage-monitoring prototype
**Status:** Current SQLite schema transcribed from backend/database.js; volatile entities from backend/server.js. Future tables and controls are proposals, not present implementation.
**Reviewed:** 24 October 2026.

> **Current/future distinction:** The source creates three SQLite tables: crops, app_settings and readings. Alerts, simulated SMS log and incidents are process-memory arrays; actions are in backend/data/actions.jsonl. There is no user/device/auth table and no authentication or authorization middleware. The schema below labels current tables separately from recommended target tables.

## 1. Data design objectives

- Store readings with provenance distinguishing synthetic, simulator and future physical-device observations.
- Associate each reading with a crop profile and site label.
- Keep threshold definitions data-driven and range-checked.
- Preserve alert evidence and lifecycle if research requires restart durability.
- Protect participant, contact and operational details through minimization and access control.
- Support exports without exposing passwords, tokens, unnecessary phone numbers or sensitive location details.
- Preserve timestamps in UTC ISO-8601 and define retention and backup responsibilities.

## 2. Current SQLite schema

### Entity relationships

- One crop profile has many readings; each reading references one crop.
- app_settings stores the active crop by name, not through a foreign key.
- There is no current relational alert/user/device table.

### crops

| Column | Type / constraint | Meaning |
|---|---|---|
| id | INTEGER PRIMARY KEY | Internal crop profile identifier |
| name | TEXT NOT NULL, UNIQUE COLLATE NOCASE | Profile name, case-insensitive unique |
| min_temp | REAL NOT NULL, CHECK -50 to 100 | Lower temperature boundary, °C |
| max_temp | REAL NOT NULL, CHECK -50 to 100 | Upper temperature boundary, °C |
| min_humidity | REAL NOT NULL, CHECK 0 to 100 | Lower RH boundary, percent |
| max_humidity | REAL NOT NULL, CHECK 0 to 100 | Upper RH boundary, percent |
| created_at | TEXT NOT NULL, UTC SQLite default | Profile creation timestamp |
| Table checks | min_temp < max_temp; min_humidity < max_humidity | Ensure ordered ranges |

### app_settings

| Column | Type / constraint | Meaning |
|---|---|---|
| key | TEXT PRIMARY KEY | Setting name, e.g. active_crop or demo-history seed marker |
| value | TEXT NOT NULL | Text-encoded setting value |

### readings

| Column | Type / constraint | Meaning |
|---|---|---|
| id | INTEGER PRIMARY KEY | Reading identifier; server currently supplies an ID |
| site | TEXT NOT NULL | Site label; not a verified site identity |
| crop_id | INTEGER NOT NULL REFERENCES crops(id) | Associated crop profile |
| temperature | REAL NOT NULL | Temperature °C; no explicit physical plausibility constraint currently |
| humidity | REAL NOT NULL CHECK 0–100 | Relative humidity percent |
| data_source | TEXT NOT NULL | Source label such as simulation, sensor or synthetic-history |
| recorded_at | TEXT NOT NULL | Timestamp string; enforce UTC/ISO format at API boundary |
| Index | readings_recorded_at_idx(recorded_at) | Supports time-based history/trend lookup |

SQLite startup settings include WAL journal mode, foreign_keys=ON and a 5000 ms busy timeout. The Node code invokes the sqlite3 command-line tool synchronously. Review this access model for performance, error handling and safe query construction before increasing concurrency.

### Current JSON mapping

Crop responses use id, commodity, minTemp, maxTemp, minHumidity and maxHumidity. Reading responses use id, site, commodity, temperature, humidity, dataSource and recordedAt.

### Persistence boundaries

| Entity/state | Current location | Restart expectation |
|---|---|---|
| Crop profiles | SQLite crops | Persisted |
| Active crop and demo-history marker | SQLite app_settings | Persisted |
| Readings | SQLite readings; latest subset also loaded into memory | Persisted; verify with controlled restart evidence |
| Trends | Derived/cached in process, reconstructed from SQLite history on startup | Verify against current revision |
| Alerts and acknowledgement | Express process memory | Lost on restart |
| Simulated SMS log | Express process memory | Lost on restart |
| Incident records | Express process memory | Lost on restart |
| Dashboard action history | JSONL file | Intended to persist; reliability/privacy need verification |
| Current user/account | Flutter local state/preferences | No authenticated server identity/session |

Do not write “all monitoring data is stored in SQLite.” State entity-specific behavior and attach restart evidence.

## 3. Recommended target relational model (not implemented)

The following additions are a design proposal based on the new Figma screens and the Flutter demo UI (phone login/OTP, farmer Accounts, My Crops and multiple linked sensors). The frontend now renders these journeys with local demo state and fixed sample sensor rows; the backend still has no OTP/auth service, farmer account ownership, device registry, pairing or live sensor records. Confirm scope, ethics/privacy impact, SMS access and sensor availability with the supervisor before adopting this target schema. Preserve the approved single-site scope unless formally changed. The screenshot explicitly states that OTP/SMS and live-sensor flows are not implemented.

| Entity | Proposed key fields and constraints |
|---|---|
| storage_sites | id, display_name, optional generalized location, timezone, created_at, active. Avoid precise location unless essential and approved. |
| farmer_accounts | id, display_name, normalized phone or account reference, status, created_at, verified_at. Restrict phone access and define recovery/deletion. Do not treat the Figma example identity as a real project record. |
| otp_challenges | id, account/phone reference, keyed code verifier or provider challenge reference, created_at, expires_at, attempts, consumed_at, resend_after, request correlation ID. Never store/log raw PIN; make it single-use, short-lived and rate-limited. Prefer a managed provider challenge if available and approved. |
| devices | id, site_id, label, device_type, status, created_at, last_seen_at, credential reference, revoked_at. Never store reusable secrets in plaintext. |
| crop_sensor_assignments | id, crop_id, device_id, assigned_at, unassigned_at, assigned_by. Enforce active assignment cardinality; if one crop per sensor at a time, enforce one active assignment per device. |
| threshold_versions | id, crop_id, version, min/max temp, min/max RH, optional exposure duration, source reference, crop stage/context, effective dates, reviewer and approval. Create a new version instead of changing a rule already used by an alert. |
| readings | Existing fields plus device_id, sequence_no, received_at, measured_at, quality_flag, request ID and optional calibration reference. Unique device/sequence or idempotency key prevents duplicate retry ingestion. |
| alerts | id, reading_id FK, threshold_version_id FK, type, severity, created_at, status, acknowledged_at/by, resolved_at, deduplication fingerprint. Preserve exact values/rules used. |
| notification_attempts | id, alert_id FK, channel, protected recipient reference, state, attempted_at, provider ID, safe error code, retry count. Distinguish queued, logged_simulation, submitted, delivered, failed. |
| users | id, account_id, normalized identity/phone reference, password hash only if password auth is also selected, status, created/updated/last-login timestamps. OTP sign-in still needs account lifecycle and recovery design. |
| roles and user_roles | role keys farmer, viewer, operator, admin, researcher; user/role links and account/site scope. |
| device_credentials | device ID, verifier/hash or secret-manager reference, creation/expiry/last-used/revoked timestamps, key version. Support rotation and revocation. |
| audit_events | id, authenticated actor or system identity, action, resource, timestamp, request correlation ID, minimized details, outcome. Append-only permissions; never trust request actor as identity. |
| incidents | id, site/crop refs, incident date, description, duration, outcome, authenticated reporter, created timestamp and data provenance. Minimize narrative and define privacy/retention. |

### Relationship rules

- A crop can classify many readings; each reading references one crop profile.
- A reading may trigger zero or more alerts; the current demo creates one alert for a breach.
- An alert may produce multiple notification attempts.
- A site can contain several devices in a future design; current scope is one site.
- A user may acknowledge alerts only with an authorized role.
- Threshold versions should remain immutable for historical interpretation. Current schema stores mutable limits directly on crops.

## 4. Data classification and handling

| Data class | Examples | Sensitivity | Recommended handling |
|---|---|---|---|
| Project metadata | Product name, generic API docs | Low | May appear in reports |
| Synthetic demo data | Seeded history, generated readings | Low but integrity-sensitive | Label synthetic; never treat as field observations |
| Operational readings | Temperature, RH, timestamp, site/device | Moderate | Minimize site detail; access control; retention and backup |
| User/account data | Email, phone, password verifier | High | Collect only if needed; hash credentials; exclude from exports/logs |
| Incident/participant data | Loss descriptions, feedback, site details | Potentially high | Ethics/consent, pseudonymize, restrict and define deletion |
| Secrets | Session token, device key, API secret | Critical | Protected config/secret manager; never commit, log or export |
| OTP challenge material | PIN, verifier, delivery destination, challenge ID | High | Never retain raw PIN; short TTL; limit attempts/resends; redact phone numbers |
| Audit/security events | Login failure, role changes, exports | Moderate/high | Minimize, protect integrity and restrict access |

Lifecycle: collect only needed fields and approvals; use protected transport for real data; restrict database and backups; separate synthetic from field data in analysis; minimize exports; establish retention and disposal with supervisor/institution.

## 5. Authentication and authorization

### Current state

- No backend authentication, session, token verification or role checks found in inspected Express code.
- Flutter login validates text locally, derives a display name and transitions to the dashboard. Password is not sent or verified. Test-user action bypasses the form.
- Crop creation/selection, alert acknowledgement, incident creation, action append and demo-breach routes are not authenticated.
- CORS is permissive in development; service binds all interfaces by default outside production; traffic is HTTP.
- Use only synthetic data on a trusted isolated demo network. The login is not security.

### Proposed decision

If real authentication is required:

1. Select local accounts or institutional identity with supervisor.
2. Validate identity server-side; never trust client-only gates or body-supplied actor.
3. Use secure browser sessions or short-lived signed tokens for mobile, HTTPS, expiry, rotation and revocation.
4. Enforce permissions in server middleware, not by hiding buttons.
5. Define least-privilege roles: viewer, operator, admin, device; scope by site if needed.
6. Rate-limit login/writes, use generic auth errors, and audit account/role changes without logging credentials.
7. Use a vetted adaptive password hash (Argon2id where supported or approved bcrypt settings); no plaintext/reversible storage.
8. If auth is out of scope, rename the UI to Demo profile and document all routes as unauthenticated and local-only.

### Proposed route permissions

| Route class | Current | Target |
|---|---|---|
| Health/static info | Public | Minimal public health only |
| Read status/history/trends | Public | viewer+ and site scoped |
| Submit sensor reading | Public | registered device identity |
| Add/edit crop limits | Public | admin, reviewed and audited |
| Select active crop | Public | operator/admin; consider per-site state |
| Acknowledge alert | Public | operator/admin with identity/time |
| Incident create/read | Public | authorized role, sensitive content protected |
| Trigger demo breach | Public | demo/admin only; disabled outside development |
| Export readings/actions | Public | authorized, audited, minimized |
| View SMS log | Public | restricted; redact destination/content |

## 6. Threat model

### Assets and boundaries

Assets: reading integrity/provenance, thresholds, availability of status/alerts, alert lifecycle, site/incident and participant records, exports, DB/log/backup, credentials, and credibility of research evidence.

Boundaries: client↔Express over HTTP; simulator/device↔reading endpoint; Express↔SQLite/JSONL; future backend↔SMS provider; project machine↔local Wi-Fi.

| Threat | STRIDE | Example | Current exposure | Mitigations/evidence |
|---|---|---|---|---|
| Fake sensor submits values | Spoofing/tampering | Reachable client submits false readings | High, no device auth | Per-device credentials, TLS/signatures, replay defense, sequence IDs, negative tests |
| Actor identity spoofing | Spoofing/repudiation | Client submits arbitrary actor to action endpoint | High; actor is body field | Derive actor from authenticated principal; audit integrity |
| Crop/threshold tampering | Tampering/elevation | Unauthenticated crop edits or selection | High | Admin checks, threshold version/review, audit and negative tests |
| Alert suppression/spam | Tampering/DoS | Unauthorized acknowledge or breach injection | High | Role checks, disable demo endpoint outside dev, rate limits, durable events |
| LAN data disclosure | Information disclosure | Read/export/SMS log accessed by another network user | High on shared LAN | Isolation, HTTPS, auth, minimization and phone/body redaction |
| MITM/credential interception | Disclosure/tampering | HTTP traffic observed/changed | HTTP current | TLS, secure token storage, endpoint validation |
| Query injection / malformed SQL | Tampering/availability | Crafted crop text reaches SQL | Manual quote helper; needs review | Parameterized driver, validation, fuzz tests, no unsafe shell interpolation |
| Resource exhaustion | DoS | Large/repeated requests or SSE clients | JSON body capped; no comprehensive rate controls | Body/query caps, rate limits, timeouts, connection caps and monitoring |
| Replay/duplicate records | Tampering/repudiation | Sensor retry creates duplicate or old measurement | No device sequence/idempotency | Device identity, idempotency key, received_at and stale/future checks |
| Synthetic data mistaken for field evidence | Repudiation/integrity | Report treats seeded points as observations | High research risk | Source labels in UI/API/export, dataset separation and report captions |
| Threshold breach mistaken for spoilage | Integrity/safety | User trusts false positive/negative as diagnosis | Simple single-reading rule; illustrative limits | Precise copy, cited limits, duration/context and domain validation |
| DB/log loss | Availability/integrity | Disk failure or partial JSONL write | Mixed storage; backup untested | Backup/restore, integrity checks, durable event transaction |
| Sensitive export leak | Information disclosure | Site/contact/actor exposed | Exports are unauthenticated | Export authorization/redaction/audit/data minimization |
| Future SMS abuse | Spoofing/DoS/cost | Compromised provider credential sends messages | No provider currently | Secret manager, quotas, recipient controls, retries/idempotency |
| Fake login assurance | Elevation/misrepresentation | User believes password protects service | High | Rename demo profile or implement server auth; explicit report caveat |
| OTP abuse or account takeover | Spoofing/elevation | PIN brute-force, SIM-swap, replay, phone enumeration or resend flooding | No OTP backend currently; design-only | Short expiry, one-time use, attempt/resend limits, generic responses, monitoring and recovery process; never return sample PIN in production |
| Cross-account sensor/data exposure | Information disclosure/elevation | Farmer changes an identifier to access another farmer’s sensor or export | Current demo has no account model | Derive owner scope from authenticated identity; authorize every lookup; negative cross-account tests |
| Sensor linking hijack | Spoofing/tampering | Attacker claims a device by guessing its ID/QR | No device registry/pairing today | Proof of possession, expiring pairing, owner approval, credential rotation/revocation and audit |

**Critical before external/field exposure:** server-side auth/authorization, TLS/private boundary, secrets, device identity, sensitive exports.
**High before collecting research data:** provenance, durable evidence, backups, retention, privacy/consent.
**Validity controls:** cited thresholds, calibration, timestamp/data-quality fields, repeatable tests.

## 7. Security checklist

### Current demo containment

- [ ] Run only on a trusted isolated network with synthetic data.
- [ ] Do not enter real account passwords into the demo login.
- [ ] Do not enter participant/site/contact/loss details without approval and protections.
- [ ] Stop the service when not demonstrating.
- [ ] Verify secrets and personal exports are not committed.
- [ ] Label synthetic output and simulated dispatch.
- [ ] Disable/protect write and demo routes if reachable beyond demo host.

### Target application controls

- [ ] Authentication is server-side or UI explicitly says demo profile.
- [ ] Route authorization matrix exists and is enforced.
- [ ] Device credentials are unique, scoped, revocable and rotated.
- [ ] HTTPS/TLS for non-isolated or real-data path.
- [ ] CORS allowlist is explicit.
- [ ] Request body/query limits, timeouts, rate limits and SSE caps are set.
- [ ] All input fields have type, range, length, enum and date validation.
- [ ] Parameterized DB access replaces manual SQL quoting for untrusted strings.
- [ ] SQL errors/stack traces are not returned to clients.
- [ ] Session/token expiry, rotation, revocation and CSRF protection are handled as applicable.
- [ ] Secrets are protected, excluded from source control and logs.
- [ ] Passwords use vetted adaptive hashing if local password auth exists.
- [ ] Login brute-force/backoff controls exist.
- [ ] OTP challenges are short-lived, single-use, rate-limited and never logged/returned; phone-number enumeration is mitigated.
- [ ] Sensor linking requires proof of device possession or approved provisioning; guessed IDs alone do not establish ownership.
- [ ] Account/sensor/crop/reading/alert/export queries enforce owner scope; cross-account access tests fail safely.
- [ ] Alert/threshold actions have trustworthy audit attribution.
- [ ] SMS body/destination are redacted in normal logs and exports.
- [ ] CSV formula injection and Markdown/HTML output encoding are reviewed.
- [ ] Errors avoid sensitive detail; logs avoid credentials and excess personal data.
- [ ] DB/backups have access restrictions and encryption where sensitive.
- [ ] Retention/deletion is defined and practiced.
- [ ] Runtime/dependencies are patched and inventoried.
- [ ] Threat model and route matrix are reviewed after material changes.

### Verification evidence to capture

- Anonymous requests denied on protected routes; insufficient role denied.
- Unknown/revoked device credentials rejected; duplicate sequence not duplicated.
- Untrusted Origin rejected where applicable.
- Oversized/malformed JSON rejected without stack trace.
- Invalid dates/numbers/strings return safe 4xx and cause no write.
- Exports omit secrets and redact protected fields; CSV formulas remain inert.
- HTTPS configuration verified beyond isolated demo.
- Backup restored and key records checked.
- Record build/hash, date, commands, outcomes and limitations.

## 8. Assumptions and limitations

This is a planning threat model, not penetration testing or a compliance opinion. No provider, physical device or public deployment is present. Institutional and legal requirements for participant/site data must be confirmed. A completed checklist is not evidence unless each item has implementation and test proof.
