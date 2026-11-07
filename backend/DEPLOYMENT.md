# Backend deployment notes

The API stores crop definitions, the selected crop, and received readings in SQLite. The backend calls the system `sqlite3` command-line program, so install SQLite 3 and ensure `sqlite3` is on `PATH`. The default file is `backend/data/storage-monitor.sqlite`; set `DATABASE_PATH` to a persistent disk path in deployments. Keep the database and its `-wal`/`-shm` sidecar files on the same host and a local filesystem. SQLite WAL does not support sharing a database file across network filesystems or multiple server hosts.

## Windows demo package

The `windows-backend` GitHub Actions job builds and smoke-tests a portable ZIP containing `Peo-Yame-Backend.exe`, a hidden backend runtime, the SQLite CLI, and a quick-start file. The launcher starts the backend in the background and remains in the Windows system tray. Its menu opens the dashboard, restarts or stops the backend, and exits the tray app. The launcher and its `runtime` folder must stay together when extracted.

Download the `peo-yame-backend-windows` artifact from a successful Actions run. User data is written under `%LOCALAPPDATA%\Peo Yame\data`, so the ZIP can live in a read-only or removable folder. On first launch, Windows may ask to allow the backend through the firewall; allow it only on private networks for phone-to-PC demo use. The package does not install a Windows service and is not intended for public hosting.

## Run for production

1. Install dependencies with `npm ci` and install SQLite 3 on the host.
2. Set `NODE_ENV=production`, `PORT`, `HOST`, `DATABASE_PATH`, and `CORS_ORIGINS` (comma-separated exact browser origins, if the browser dashboard is used). Set `TRUST_PROXY=true` only when a trusted reverse proxy forwards `X-Forwarded-For`, so login throttling keys on the client address rather than the proxy.
3. Put the API behind an HTTPS reverse proxy and allow sensor/app traffic only through the intended network path.
4. Back up the database using SQLite's online backup API or a coordinated backup procedure. Do not copy only the main database file while it is actively using WAL mode.

Production mode disables the fake sensor generator and synthetic trend baseline. It binds to loopback unless `HOST` is explicitly set. Development mode retains simulated readings for demos. Crop definitions and readings survive restarts; request values are validated and SQL string values are escaped before being passed to SQLite.

Farmer accounts use Botswana phone numbers and passwords when `AUTH_ENABLED=true` or `NODE_ENV=production`; passwords are salted and hashed, and bearer sessions expire and can be revoked. Authenticated crop sites and sensor links are owner-scoped. Demo entry remains session-free. This is still a small demonstration service, not a production security review: login throttling is process-local, data is not encrypted at rest by the app, there is no SMS provider or device credential enrollment, and global dashboard readings are shared demo data rather than farmer-isolated telemetry. Use HTTPS, private network controls and a security review before handling real farmer data or exposing the service publicly.
