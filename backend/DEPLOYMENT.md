# Backend deployment and security notes

## Local demonstration

Install Node.js 18+ and SQLite 3, with `sqlite3` on `PATH`:

```bash
npm ci
npm run demo
```

Demo mode generates simulated readings and synthetic trend history. It binds
to loopback and detected private IPv4 interfaces. The database defaults to
`backend/data/storage-monitor.sqlite`; `DATABASE_PATH` can select another
local path. SQLite WAL files must stay on the same host and local filesystem.

## Demo account flow

Both clients show a **Demo mode** button that opens the shared account without
login. The profile is **Mr Lesego Lefoko** (`LLefoko@email.co.bw`). Demo mode
does not request a phone number, password, authenticator or QR, and does not
issue or require session tokens. Authentication endpoints return not found in
demo mode. Crop locations and sensor assignments are saved under this shared
demo account.

## Production account flow

Production retains phone verification, email/password credentials, Google
Authenticator and one-use QR pairing. Passwords use Node `scrypt` with a random
salt; raw passwords are not stored. Password sign-in is rate-limited by email
for five failed attempts per five-minute window. Farmer sessions expire after
seven days; SQLite stores only a SHA-256 token hash. Active QR and OTP
challenges remain in process memory.

## Production limitations

Set `NODE_ENV=production`, configure `HOST`, `PORT`, `DATABASE_PATH`, and
`CORS_ORIGINS`, and place the service behind HTTPS before remote access. In
production, phone verification returns an error until an SMS provider is
configured. Configure account/session recovery, revocation, monitoring, backup,
and abuse controls before public deployment.

The global monitor/status/reading/alert routes are not account-scoped even
though farmer profile and crop-assignment routes require a farmer session.
Sensor IDs are discovered from submitted reading site fields, not verified
device credentials. The default HTTP configuration and unauthenticated demo
mode are for controlled local demonstrations only; demo data has no account
isolation.
