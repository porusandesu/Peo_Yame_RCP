# Peo Yame

Peo Yame is a storage-monitoring prototype with a shared Express/SQLite backend, responsive web dashboard, Flutter Android client, and Windows notification-area launcher.

The implementation and acceptance criteria follow the Peo Yame parity and QR prompt supplied for this build. Demo readings are synthetic. SMS is not sent. Storage estimates are unvalidated heuristics and require manual crop checks.

## Build verification

GitHub Actions builds the Android APK and a standalone Windows executable and runs backend, Flutter, and tray lifecycle checks. See Actions artifacts for each versioned build.

## Run the web dashboard and backend from source

Install Node.js 22 or newer. From the repository root, run:

```sh
npm --prefix backend install
npm start
```

Open `http://127.0.0.1:3000/` in a browser. The dashboard and `/api` endpoints
are served by the same backend process. Confirm startup at
`http://127.0.0.1:3000/api/health`. Keep the terminal open while using the
dashboard; press Ctrl+C to stop the backend. The SQLite database is stored in
`backend/data/` by default. Set `PEO_YAME_DATA_DIR` to choose another writable
directory.

## Windows app

Download and launch `Peo Yame vN.exe`. It contains the backend runtime, database
driver, web dashboard, brand assets, and Windows host. On launch it prepares its
private runtime files automatically, selects an available local port, starts the
backend, and opens the dashboard in the default browser. No separate Node.js
installation or file extraction is needed. The notification-area menu also has
Start, Restart backend, Stop, and Quit actions. App data is kept under
`%LOCALAPPDATA%\Peo Yame`; startup details are written to its `data\logs\app.log`.
