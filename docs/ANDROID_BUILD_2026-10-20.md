# Android release build evidence

> Historical evidence for the nested `flutter_application_1` project from 20 October 2026. It does not describe or validate the current top-level Flutter application; see the [current test report](TEST_REPORT.md).

**Date:** 20 October 2026
**Project:** `flutter_application_1` on branch `pauls-branch`
**Flutter:** 3.47.7
**Java used for build:** Eclipse Temurin JDK 17.0.20.1 at `/home/porusandesu/.local/jdk/jdk-17.0.20.1+1`

Command: `flutter build apk --release`

**Result:** Pass. APK: [`app-release.apk`](../flutter_application_1/build/app/outputs/flutter-apk/app-release.apk), 52,337,896 bytes (52.3 MB), built 20 October 2026 at 14:50:32 +0200.

SHA-256: `7f952570a652eb3019c55d212b2ca736ab4e875e2e1739546205186dbc9797c8`

The host's default `java` command still resolves to OpenJDK 8; JDK 17 was selected explicitly for the build. Gradle initially exceeded this 3.6 GiB machine's available memory with its default 8 GiB heap and its daemon exited. Reducing the Gradle heap to 1 GiB, limiting it to one worker, disabling parallel builds, and compiling Kotlin in-process allowed the release APK to build.

Flutter emitted a Kotlin Gradle Plugin compatibility warning for `share_plus`. The APK was built but was not installed or exercised on a physical phone. Network reachability, saved-address behavior, and on-device use remain unverified.
