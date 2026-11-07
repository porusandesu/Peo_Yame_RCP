# Backend deployment notes

The API stores crop definitions, the selected crop, and received readings in SQLite. The backend calls the system `sqlite3` command-line program, so install SQLite 3 and ensure `sqlite3` is on `PATH`. The default file is `backend/data/storage-monitor.sqlite`; set `DATABASE_PATH` to a persistent disk path in deployments. Keep the database and its `-wal`/`-shm` sidecar files on the same host and a local filesystem. SQLite WAL does not support sharing a database file across network filesystems or multiple server hosts.

## Run for production

1. Install dependencies with `npm ci` and install SQLite 3 on the host.
2. Set `NODE_ENV=production`, `PORT`, `HOST`, `DATABASE_PATH`, and `CORS_ORIGINS` (comma-separated exact browser origins, if the browser dashboard is used).
3. Put the API behind an HTTPS reverse proxy and allow sensor/app traffic only through the intended network path.
4. Back up the database using SQLite's online backup API or a coordinated backup procedure. Do not copy only the main database file while it is actively using WAL mode.

Production mode disables the fake sensor generator and synthetic trend baseline. It binds to loopback unless `HOST` is explicitly set. Development mode retains simulated readings for demos. Crop definitions and readings survive restarts; request values are validated and SQL string values are escaped before being passed to SQLite.

This prepares persistent data and deployment configuration; it does not provide production user authentication or authorization. The app currently provides a direct demo entry only. Do not expose this API to the public internet until account authentication, API authorization, and per-device credentials are implemented and tested.
