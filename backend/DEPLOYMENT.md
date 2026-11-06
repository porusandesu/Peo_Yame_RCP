# Backend deployment notes

The API stores crop definitions, the selected crop, readings, farmer accounts, crop locations, sensor assignments, and hashed bearer sessions in SQLite. Web and mobile clients share these records when they connect to the same backend; each device signs in separately with the same farmer phone number. The backend calls the system `sqlite3` command-line program, so install SQLite 3 and ensure `sqlite3` is on `PATH`. The default file is `backend/data/storage-monitor.sqlite`; set `DATABASE_PATH` to a persistent disk path in deployments. Keep the database and its `-wal`/`-shm` sidecar files on the same host and a local filesystem. SQLite WAL does not support sharing a database file across network filesystems or multiple server hosts.

## Run for production

1. Install dependencies with `npm ci` and install SQLite 3 on the host.
2. Set `NODE_ENV=production`, `PORT`, `HOST`, `DATABASE_PATH`, and `CORS_ORIGINS` (comma-separated exact browser origins, if the browser dashboard is used).
3. Put the API behind an HTTPS reverse proxy and allow sensor/app traffic only through the intended network path.
4. Back up the database using SQLite's online backup API or a coordinated backup procedure. Do not copy only the main database file while it is actively using WAL mode.

Production deployments disable the fake sensor generator and synthetic trend baseline, and bind to loopback unless `HOST` is explicitly set. Packaged Windows demo builds bind only to loopback and detected private IPv4 interfaces so local phones can pair without opening a listener on public interfaces. Development mode retains simulated readings for demos. Crop writes use validated, parameterized SQL statements and survive restarts.

The local browser and packaged Windows dashboard use a demonstration OTP flow: the server creates a random, expiring PIN and displays it locally. It does not send SMS. In production deployments, OTP requests return an error until an SMS provider is configured. Farmer routes require a seven-day bearer session; only a hash of each token is persisted, so existing devices remain signed in across backend restarts. This is a starting point, not production identity management; configure SMS delivery, session revocation, HTTPS, rate limiting and device credentials before public deployment. Existing monitoring and sensor-ingestion routes are still not account-scoped.
