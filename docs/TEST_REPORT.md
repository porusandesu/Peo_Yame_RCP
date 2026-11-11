# Test report

## GitHub Actions v69

Run: https://github.com/porusandesu/Peo_Yame_RCP/actions/runs/43050967745

- Backend tests: passed.
- Android test/analyze job: failed during Dart parsing. CI identified an invalid nullable-map fallback expression, unsupported font-weight constant, and empty catch clause. These have been corrected in the follow-up source.
- Windows package/self-test: failed at the lifecycle self-test. CI v69 did not preserve the diagnostic output, so the follow-up writes backend and lifecycle details to the Actions log.

No application code, build or tests were run locally. Results for fixes remain pending a new Actions run.