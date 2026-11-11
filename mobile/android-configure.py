from pathlib import Path
p=Path("android/app/src/main/AndroidManifest.xml")
s=p.read_text()
s=s.replace("<application", "<application android:usesCleartextTraffic=\"true\"")
p.write_text(s)
