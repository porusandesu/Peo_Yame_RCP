# Peo Yame brand assets

The supplied `Peo_Yame_logo_assets/Peo_Yame_Dev_Assets` package is the source
for the app's platform icons. Its integration notes and original master artwork
are kept alongside the package.

- Android density launcher icons, round icons and adaptive foreground/background
  are installed under `android/app/src/main/res/`; the manifest references both
  standard and round launcher icons.
- The Windows Flutter runner uses `windows/runner/resources/app_icon.ico`.
- The web app uses the supplied 16–512 px icons under `web/icons/` and declares
  the supported sizes in `web/manifest.json`; the browser tab and Apple touch
  icon use the matching supplied artwork.
- The Play Store 512 px icon and brand masters remain in the supplied package
  for store submissions and future brand use.

Build the platform again to see the updated launcher/application icons.
