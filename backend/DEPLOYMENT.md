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

## Current account flow

- Web account creation starts with phone verification. The local demo does not
  send SMS and does not return the demo PIN. After requesting verification, the
  web page offers **Skip verification (demo)**. This route is disabled in
  production.
- Accounts without a password can set an email and password after phone
  verification. Passwords use Node `scrypt` with a random salt; raw passwords
  are not stored. Password sign-in is rate-limited by email for five failed
  attempts per five-minute window.
- Existing farmers can also sign in with Google Authenticator when enabled.
- Mobile sign-in uses a one-use QR challenge issued only by an authenticated
  web account. It expires after two minutes. The signed-out app has no OTP or
  manual backend-address sign-in path.
- Farmer sessions expire after seven days. Only a SHA-256 token hash is stored
  in SQLite. Account email/password and farmer metadata persist across backend
  restarts; active QR challenges and OTP challenges are held in process memory.

## Production limitations

Set `NODE_ENV=production`, configure `HOST`, `PORT`, `DATABASE_PATH`, and
`CORS_ORIGINS`, and place the service behind HTTPS before remote access. In
production the demo bypass is unavailable and OTP requests return an error
until an SMS provider is configured. Configure account/session recovery,
revocation, monitoring, backup, and abuse controls before public deployment.

The global monitor/status/reading/alert routes are not account-scoped even
though farmer profile and crop-assignment routes require a farmer session.
Sensor IDs are discovered from submitted reading site fields, not verified
device credentials. The default HTTP configuration and demo authentication
flow are for controlled local demonstrations only.
