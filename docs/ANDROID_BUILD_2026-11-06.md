# Android build evidence

> Historical local build record for commit `ff9e76f`. The latest automated build evidence is GitHub Actions run `42360332399` for the current account and pairing changes; see [test report](TEST_REPORT.md).

**Date:** 6 November 2026  
**Source:** `pauls-branch`, based on commit `ff9e76fdf2892de94a4e890df20ea76467c90e9c`; the Gradle memory adjustment is recorded in the accompanying source change.  
**Target:** root Flutter application (`lib/`), not the older nested `flutter_application_1/` app.

Command:

```bash
JAVA_HOME=/home/porusandesu/.local/jdk/jdk-17.0.20.1+1 \
PATH=/home/porusandesu/.local/jdk/jdk-17.0.20.1+1/bin:$PATH \
flutter build apk --release --no-pub
```

**Result:** Build succeeded. Artifact: [`app-release.apk`](../build/app/outputs/flutter-apk/app-release.apk), 52.8 MB.  
**SHA-256:** `652dc1899dcfd1ac01e1acdfde5be739fd86d124c92cb6a1ad562e07f5dda980`

The root `android/gradle.properties` requests a 1 GB Gradle heap, one worker, no parallel build, and in-process Kotlin compilation so the build fits the available machine. Flutter reports that Gradle 8.14.0, Android Gradle Plugin 8.11.1, and Kotlin 2.2.20 will soon fall below its supported minimums.

## Distribution limits

- The APK uses application ID `com.example.storage_monitor_flutter` and the debug signing key. It is suitable for sideloading as a controlled prototype, not Play Store submission or an upgrade path for a production app.
- The app uses plain HTTP for the local demo backend. Keep it on an isolated demo network.
- The APK has not been installed or exercised on a physical phone. Backend reachability, device-specific behavior, and the full demo flow remain unverified.
- This build does not add physical sensor input, real SMS delivery, or server-authenticated accounts.
