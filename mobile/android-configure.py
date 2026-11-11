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
application.set(f"{{{ANDROID_NS}}}icon", "@mipmap/ic_launcher")
application.set(f"{{{ANDROID_NS}}}roundIcon", "@mipmap/ic_launcher_round")
tree.write(manifest, encoding="utf-8", xml_declaration=True)
