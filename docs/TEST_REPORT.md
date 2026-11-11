# Test report

## GitHub Actions v77

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43081552333
Commit: `c1f01a3e737a12aebc3a880eccced887c17cabe4`.

- Backend tests: passed.
- Android widget test and analyzer: passed; Android release APK built and uploaded as `Peo Yame v77 Android`.
- Windows packaged backend lifecycle test: passed; ZIP uploaded as `Peo Yame v77 Windows`.
- This run verifies the backend regex and Android compile/API corrections. It does not cover the pending design pass, full QR security, installer, encryption, sensors, or manual visual/device checks.
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
