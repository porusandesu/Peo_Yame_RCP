#!/usr/bin/env bash
# Builds the phone APK. Run from anywhere:  bash build_apk.sh
set -e
export JAVA_HOME="$HOME/.local/jdk/jdk-17.0.20.1+1"
export PATH="$HOME/flutter/bin:$JAVA_HOME/bin:$PATH"
cd "$(dirname "$0")"

java -version 2>&1 | head -1
(cd android && ./gradlew --stop || true)   # kill any stale Java 25 daemon
flutter clean
flutter pub get
flutter build apk --release

echo
echo "APK: $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
echo "Install: adb install -r build/app/outputs/flutter-apk/app-release.apk"
