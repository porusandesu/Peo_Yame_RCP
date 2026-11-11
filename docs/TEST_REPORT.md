# Test report

## GitHub Actions v73

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43053668232

- Backend tests: passed.
- Android widget test, analyzer, and release APK build: passed.
- Windows publish and lifecycle self-test: passed.
- Artifacts uploaded: Peo Yame v73 Android (33,747,826 bytes) and Peo Yame v73 Windows (171,213,971 bytes).

The Windows self-test verified health after start and restart, retained account login, reset storage locations on restart, and stopped the server. It does not interact with the tray menu or verify browser launching or Quit.

## Current work

QR pairing endpoints and initial web/Android flow support are being added. These changes have not yet been verified by Actions. Full parity requirements including TOTP, active-session management, sensor key/link lifecycle, exports, full SSE updates, inspection reminders, offline fallback, and Guided Demo run-sheet actions remain open until implemented and tested.

No application builds or tests are run on the development machine.