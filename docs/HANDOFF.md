# Handoff — Peo Yame Storage Monitor

Updated: 6 November 2026

## Workspace

- Project: `/home/porusandesu/Documents/storage_monitor_flutter`
- Branch: `exe-work`
- Baseline before the profile/navigation update: `ffa1f80` — `Preserve packaged payload when branding Windows runtime`.
- Check `git log` and `git status` for the current pushed revision.

## Current worktree

The profile and navigation update adds farmer phone editing, refreshes farmer
crop/sensor data after changes, and adds Accounts and My Crops navigation. The
backend dashboard edit controls use unique selectors. Branding assets are in
`assets/branding/` and are declared in `pubspec.yaml`.

Recent project notes describe Windows backend packaging, mobile QR pairing and
sign-in, farmer accounts and crop sensor assignments, app reconnect handling,
and Peo Yame branding. See [changes-2026-11-06.md](changes-2026-11-06.md).

## Build and verification evidence

- [ANDROID_BUILD_2026-11-06.md](ANDROID_BUILD_2026-11-06.md) records a successful
  root Flutter release APK build (52.8 MB) and SHA-256
  `652dc1899dcfd1ac01e1acdfde5be739fd86d124c92cb6a1ad562e07f5dda980`.
- That build evidence names source `pauls-branch` at `ff9e76f`; the current
  checkout is `exe-work` at `ffa1f80` with additional local edits. Do not treat
  the recorded APK as proof that these worktree edits are included.
- The changes note records successful Windows backend packaging/upload in
  GitHub Actions run [42261817394](https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/42261817394).
- It also records `dart analyze` with informational notices, successful
  `node --check` for backend/dashboard JavaScript, and `git diff --check`.
- The APK was not installed or exercised on a physical phone. SMS delivery,
  physical sensor input, and production account security are not implemented.

## Suggested continuation

1. Compare the current source with the successful build's source revision; if a
   fresh artifact is needed, rebuild from this checkout and record its hash.
2. Review the mobile account/QR flows and backend changes, then verify them in
   the intended local-network demo. Prior notes do not establish device-level
   behavior for the current worktree.
3. Keep the prototype on a controlled demo network: it uses plain HTTP and
   local demo OTP behavior.

## Project documentation

Start with the root [README](../README.md), then consult
[architecture](ARCHITECTURE.md), [risk register](RISK_REGISTER.md),
[baseline audit](BASELINE_AUDIT.md), and [test report](TEST_REPORT.md).
