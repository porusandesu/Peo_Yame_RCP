# Test report

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