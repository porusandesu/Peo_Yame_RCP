# Peo Yame build handoff

Source-of-truth requirements: the owner supplied Peo Yame parity and QR prompt, with three SVG references. Existing application source was discarded for this rebuild; the implementation is being authored from the supplied requirements. Keep the original logo image in assets.

Do not run builds or tests on the development machine. Push the consolidated source to exe-work and verify backend, Android, Windows, lifecycle, and feature behavior through GitHub Actions. Update docs/TEST_REPORT.md only with observed CI results.

Open requirements currently include both complete QR approval flows, TOTP, active sessions, sensors, exports, cross-client events and offline behavior, crop-inspection reminders, deeper demo tools, and full functional tray lifecycle assertions. Do not describe these as complete until tested.
