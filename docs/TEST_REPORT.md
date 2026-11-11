# Test report

## GitHub Actions v77

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43081552333
Commit: `c1f01a3e737a12aebc3a880eccced887c17cabe4`.

- Backend tests: passed.
- Android widget test and analyzer: passed; Android release APK built and uploaded as `Peo Yame v77 Android`.
- Windows packaged backend lifecycle test: passed; ZIP uploaded as `Peo Yame v77 Windows`.
- This run verifies the backend regex and Android compile/API corrections. It does not cover the pending design pass, full QR security, installer, encryption, sensors, or manual visual/device checks.
- No local app builds or tests were run.

## GitHub Actions v78 — failed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43086745905
Commit: `7a29c8368d1979e0bd4a2d84f1082d77f6e39117`.

- Backend and Windows jobs failed because a static web assertion expected the mobile-only Welcome heading on the web split sign-in gate. The backend estimate assertions passed.
- Android widget compilation failed because the welcome logo container used an integer for `Container.padding` instead of `EdgeInsets`.
- Both source issues were corrected in v79. No local app builds or tests were run.

## GitHub Actions v79 — passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43087493893
Commit: `268ac26fab580ee73caa7150ade20611eda1c929`.

- Backend API tests passed, including dashboard root and estimate disclaimer checks.
- Windows tray package test passed, including startup, `/api/health`, and dashboard HTML checks. Artifact was a ZIP with separate runtime files; this is superseded by the requested standalone executable work.
- Android analysis passed and release APK artifact was produced.
- The v79 Windows lifecycle check did not observe opening the system browser; browser launch was not part of that automated self-test.
- No local app builds or tests were run.

## GitHub Actions v80 — failed during active-session implementation

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43089055834
Commit: `415515c8d28c6fdf798d3c201fc57b94e036acc5`.

- Backend test expected one session after the test had performed both registration and another successful login; actual session count was two.
- Android compilation found a parenthesis error in the new Active sessions dialog.
- Windows stopped at the same backend test failure. Both identified issues were corrected in v81.

## GitHub Actions v81 — passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43089422093
Commit: `a30686b7558ff23eab6ed31ab8fb47e8d6a0475d`.

- Backend tests passed for session listing, current-device identification, per-device revocation, revoke-other-sessions, and cross-account revocation rejection.
- Android widget test, analyzer, and release APK build passed; artifact `Peo Yame v81 Android` uploaded.
- Windows backend packaging and lifecycle self-test passed; artifact `Peo Yame v81 Windows` uploaded. This is still the ZIP format and does not verify the new standalone executable.
- No local app builds or tests were run.

## GitHub Actions v82 — Windows publish failed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43090910626
Commit: `a7e8e417d5b78492a3adf4ba4b6079bcd2a19c32`.

- Backend tests passed.
- Android analysis passed; the release build was still running when Windows publish failed.
- Windows prepared the embedded bundle, then publish failed because MSBuild resolved the relative embedded-resource paths from `windows/` and could not find `PeoYame.bundle.zip`. No standalone artifact or startup check was produced.
- The workflow now resolves the bundle and icon to absolute paths before publish. This correction is not yet CI-verified.
- No local app builds or tests were run.

## GitHub Actions v83 — passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43091285867
Commit: `d183d386ce00547924b09dc3ddb1b5be2d476150`.

- Backend tests passed.
- Windows published a 107,262,737-byte self-contained executable. The workflow copied only that executable to an isolated folder and successfully started it; its embedded runtime served both `/api/health` and the dashboard HTML, then passed account, restart, reset, and stop checks. Artifact `Peo Yame v83 Windows` uploaded.
- Android widget test, analyzer and release APK passed; artifact `Peo Yame v83 Android` uploaded.
- The executable did not yet exercise the browser-launch request; v84 adds that assertion.
- No local app builds or tests were run.

## GitHub Actions v84 — passed

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43092378309
Commit: `37e05713a702191d56061d6d7a118a66e23ee0f6`.

- Backend tests passed.
- Windows isolated standalone startup, embedded backend/dashboard and dashboard URL launch-request checks passed. Artifact `Peo Yame v84 Windows` uploaded (107,264,219 bytes).
- Android widget test, analyzer and release APK passed; artifact `Peo Yame v84 Android` uploaded.
- CI verified the launch request was recorded, but did not observe a visible desktop browser.
- No local app builds or tests were run.

## GitHub Actions v69

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43050967745

- Backend tests: passed.
- Android failed on Dart syntax errors, corrected in the next revision.
- Windows publish succeeded, but the lifecycle self-test step failed.

## GitHub Actions v70

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43051496142

- Backend tests: passed.
- Android syntax was corrected; the widget test revealed the demo action was below the initial welcome viewport. The welcome layout was then simplified.
- Windows self-test failed; the log output did not expose its return reason.

## GitHub Actions v71

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43052045739

- Backend tests passed.
- Android widget test and analyzer passed; release APK artifact `Peo Yame v71 Android` was uploaded (33,747,844 bytes).
- Windows self-test still failed. The next workflow uses Start-Process to read the GUI executable's actual exit code and writes a marker when its entry point starts.

## GitHub Actions v72

Pending at the time of this report. No result is claimed.

No app build or test commands were run on the development machine.

## GitHub Actions v85

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43094194736

- Backend API test job passed, including the crop-inspection reminder scenarios.
- Windows backend packaging and isolated single-executable lifecycle verification passed; artifact upload completed.
- Android test/analyzer and release build passed; APK upload was in progress at the last status check.
- v85 does not include sensor management changes; those are pending a subsequent Actions run.
- No app build or test commands were run on the development machine.

## GitHub Actions v86 (sensor management)

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43095622399

- Queued behind the v85 Android artifact upload at the time v87 source work began; no result is claimed yet.
- Includes account-owned sensor registration, location linking/unlinking, demo sensor reading and authorization coverage, and web/Android client changes.

## GitHub Actions v87 (reading exports)

Pending commit and CI. Source adds account-scoped CSV and Markdown endpoints, web downloads, Android clipboard export, and API format checks. No result is claimed yet.
