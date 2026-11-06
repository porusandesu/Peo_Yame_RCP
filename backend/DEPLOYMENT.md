# Backend deployment notes

The API stores crop definitions, the selected crop, readings, farmer accounts, crop locations, and sensor assignments in SQLite. The backend calls the system `sqlite3` command-line program, so install SQLite 3 and ensure `sqlite3` is on `PATH`. The default file is `backend/data/storage-monitor.sqlite`; set `DATABASE_PATH` to a persistent disk path in deployments. Keep the database and its `-wal`/`-shm` sidecar files on the same host and a local filesystem. SQLite WAL does not support sharing a database file across network filesystems or multiple server hosts.

## Run for production

1. Install dependencies with `npm ci` and install SQLite 3 on the host.
2. Set `NODE_ENV=production`, `PORT`, `HOST`, `DATABASE_PATH`, and `CORS_ORIGINS` (comma-separated exact browser origins, if the browser dashboard is used).
3. Put the API behind an HTTPS reverse proxy and allow sensor/app traffic only through the intended network path.
4. Back up the database using SQLite's online backup API or a coordinated backup procedure. Do not copy only the main database file while it is actively using WAL mode.

Production mode disables the fake sensor generator and synthetic trend baseline. It binds to loopback unless `HOST` is explicitly set. Development mode retains simulated readings for demos. Crop writes use validated, parameterized SQL statements and survive restarts.

The browser dashboard has a local demonstration OTP flow: the server creates a random, expiring PIN and returns it to the browser only outside production mode. It does not send SMS. In production, OTP requests return an error until an SMS provider is configured. Farmer account, crop and sensor-registration routes require a seven-day in-memory bearer session, which is lost when the server restarts. This is a starting point, not production identity management; configure SMS delivery, persistent/revocable sessions, HTTPS, rate limiting and device credentials before public deployment. Existing monitoring and sensor-ingestion routes are still not account-scoped.
