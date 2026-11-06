# Handoff — Peo Yame Storage Monitor

Updated: 7 November 2026

## Workspace

- Project: `/home/porusandesu/Documents/storage_monitor_flutter`
- Branch: `exe-work`
- Baseline before this update: `833fc13` — `Improve farmer profile and crop navigation`.
- Check `git log` and `git status` for the current pushed revision.

## Current worktree

This update replaces the Windows runner placeholder icon, keeps the packaged
backend reachable only through loopback and detected private IPv4 interfaces,
and verifies QR backend connectivity before saving it. Farmer sessions now
persist as token hashes in SQLite, and both clients refresh profile changes
from the shared backend. The web hamburger opens Settings with profile editing,
simulation and export actions. The mobile Settings tab replaces Accounts,
includes Data exports, and shares the corrected crop navigation. Both trend
charts scale their temperature and humidity axes from the selected crop limits.

Recent project notes describe Windows backend packaging, mobile QR pairing and
sign-in, farmer accounts and crop sensor assignments, app reconnect handling,
and Peo Yame branding. See [changes-2026-11-06.md](changes-2026-11-06.md).

## Build and verification evidence

- [ANDROID_BUILD_2026-11-06.md](ANDROID_BUILD_2026-11-06.md) records a successful
  root Flutter release APK build (52.8 MB) and SHA-256
  `652dc1899dcfd1ac01e1acdfde5be739fd86d124c92cb6a1ad562e07f5dda980`.
- That build evidence names source `pauls-branch` at `ff9e76f`; it does not
  include the later `exe-work` profile, connection, navigation or chart changes.
- The changes note records successful Windows backend packaging/upload in
  GitHub Actions run [42261817394](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42261817394).
- `dart format` and backend/dashboard JavaScript syntax checks pass for the
  current update. `dart analyze` timed out without returning diagnostics.
- The APK was not installed or exercised on a physical phone. SMS delivery,
  physical sensor input, and production account security are not implemented.

## Suggested continuation

1. Build the Windows backend artifact and Windows Flutter app from this branch
   so the new packaged icon and LAN pairing behavior reach users.
2. Verify phone pairing, OTP, cross-device profile refresh and crop-specific
   charts on a PC and physical phone. This update has not been exercised on a
   physical device.
3. Keep the prototype on a controlled demo network: it uses plain HTTP and
   local demo OTP behavior.

## Project documentation

Start with the root [README](../README.md), then consult
[architecture](ARCHITECTURE.md), [risk register](RISK_REGISTER.md),
[baseline audit](BASELINE_AUDIT.md), and [test report](TEST_REPORT.md).
