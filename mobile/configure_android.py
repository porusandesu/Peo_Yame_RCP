from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
if "android.permission.CAMERA" not in text:
    text = text.replace("<application", '<uses-permission android:name="android.permission.CAMERA" />\n    <uses-permission android:name="android.permission.INTERNET" />\n    <application android:usesCleartextTraffic="true" android:allowBackup="false"', 1)
manifest.write_text(text)
activities = list(Path("android/app/src/main/kotlin").rglob("MainActivity.kt"))
if not activities:
    raise SystemExit("Flutter Android MainActivity was not generated")
for activity in activities:
    src = activity.read_text()
    src = src.replace("io.flutter.embedding.android.FlutterActivity", "io.flutter.embedding.android.FlutterFragmentActivity")
    src = src.replace("FlutterActivity", "FlutterFragmentActivity")
    activity.write_text(src)
