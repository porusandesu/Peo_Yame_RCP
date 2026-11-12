from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)

resource_root = Path("android/app/src/main/res")
brand_root = Path("android-brand/res")
for source in brand_root.iterdir():
    if source.is_dir():
        shutil.copytree(source, resource_root / source.name, dirs_exist_ok=True)

manifest = Path("android/app/src/main/AndroidManifest.xml")
tree = ET.parse(manifest)
application = tree.getroot().find("application")
if application is None:
    raise RuntimeError("Generated Android manifest has no application element.")
application.set(f"{{{ANDROID_NS}}}usesCleartextTraffic", "true")
application.set(f"{{{ANDROID_NS}}}label", "Peo Yame")
application.set(f"{{{ANDROID_NS}}}icon", "@mipmap/ic_launcher")
application.set(f"{{{ANDROID_NS}}}roundIcon", "@mipmap/ic_launcher_round")
tree.write(manifest, encoding="utf-8", xml_declaration=True)

# local_auth (device-credential confirmation before approving a computer
# sign-in) requires the activity to be a FlutterFragmentActivity.
for main_activity in Path("android/app/src/main/kotlin").rglob("MainActivity.kt"):
    text = main_activity.read_text(encoding="utf-8")
    if "FlutterFragmentActivity" in text:
        continue
    text = text.replace("FlutterActivity", "FlutterFragmentActivity")
    if "import io.flutter.embedding.android.FlutterFragmentActivity" not in text:
        text = text.replace(
            "package ",
            "import io.flutter.embedding.android.FlutterFragmentActivity\npackage ",
            1,
        )
    main_activity.write_text(text, encoding="utf-8")

# Keep classic resource file paths in release APKs so packaged assets stay
# inspectable (newer AGP shortens them by default).
gradle_props = Path("android/gradle.properties")
props = gradle_props.read_text(encoding="utf-8")
if "enableResourceOptimizations" not in props:
    gradle_props.write_text(props + "\nandroid.enableResourceOptimizations=false\n", encoding="utf-8")
