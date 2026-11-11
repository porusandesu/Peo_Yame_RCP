# Test report

## GitHub Actions v69

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43050967745

- Backend tests: passed.
- Android test/analyze job: failed during Dart parsing; the invalid nullable-map fallback, unsupported font-weight constant, and empty catch clause were corrected in the next commit.
- Windows packaging and lifecycle self-test failed. The job did not emit the caught exception; diagnostic output is being added.

## GitHub Actions v70

The backend tests passed again. Android syntax was corrected; its widget test then failed because the demo action was below the initial welcome viewport. The welcome screen is being simplified to show the demo and account entry actions immediately. Windows lifecycle verification still failed; v71 will emit the internal self-test error for correction.

No app code, build or tests were run locally.