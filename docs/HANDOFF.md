# Project handoff

**Working branch:** `pauls-branch`
**Starting commit:** `65d308c` (`Prepare and document Android release build`)
**Status:** first rebuilding increment in progress; GitHub Actions verification pending.

## Changes in this increment

- Replaced the mobile demo phone/PIN gate with a direct **Demo mode** button.
- Removed the web demo's pretend OTP and profile-creation screens; its **Demo mode** button opens the dashboard as Mr Lesego Lefoko (`LLefoko@email.co.bw`).
- Added the same shared display profile to mobile.
- Added 24 starter crop profiles for grains, pulses, oilseeds, vegetables, and fruits, including separate grain-moisture guidance and caveat notes.
- Removed the mobile's numeric crop-quality and remaining-days estimates. Readings are presented against target bands with crop notes.
- Added Flutter test/analyzer and Node backend test/check jobs to GitHub Actions.

## Important known gaps

- Real phone login, account creation, phone verification, and bidirectional QR single sign-on are not implemented in this revision. No dummy login flow should be reintroduced. Design these with backend account/session tests before adding client login screens.
- The demo profile is client-side display data. It does not authenticate a farmer or isolate data.
- The backend still has globally selected crop/threshold state and no per-site authorization. It is a local demonstration service, not safe for public deployment.
- No physical sensors or SMS provider are connected. Simulated values and alert logs must remain labelled as demo data.
- Crop target bands are starter references, not Botswana-validated spoilage limits. Refer to [BOTSWANA_CROP_STORAGE_PACKAGE.md](BOTSWANA_CROP_STORAGE_PACKAGE.md).

## Verification

Local builds/tests were not run because the user asked to use GitHub Actions for testing. The workflow was expanded to run Flutter widget tests, Dart analysis, Android debug APK build, backend syntax checks, and backend tests. Record the run URL, each job's conclusion, and any artifact link here after pushing and fixing failures.

## Next implementation steps

1. Get the GitHub Actions run green and save its evidence in [TEST_REPORT.md](TEST_REPORT.md).
2. Build a small backend account/session layer with a tested first-account path that has no SMS dependency. Keep demo access separate and session-free.
3. Add phone-number login and new-account setup to both clients, then test invalid credentials, account creation, session restore/expiry, and logout in CI.
4. Add one-time, expiring QR SSO challenges and test web-to-phone and phone-to-web flows against the backend.
5. Replace global crop/reading ownership with storage-site and sensor association before field use; add negative authorization tests and HTTPS deployment guidance.

## Workspace note

The pre-existing untracked `backend/vendor/sqlite3.exe` was present when switching branches and has been left untouched. It is not part of this increment.
