# Peo Yame — Complete Development Asset Package

This package contains ready-to-drop branding assets for Android, Windows and Web/PWA.

## Included
- Android launcher icons + round icons
- Android adaptive icon foreground/background
- Google Play 512x512 icon
- Windows square logo sizes
- Windows ICO
- Web/PWA/favicons
- Light monochrome master
- Sorghum branding sheet
- SVG container
- Integration READMEs

## Brand direction
Peo Yame uses a sorghum-centered agricultural identity, with temperature and humidity monitoring cues for harvest preservation.

## Quick integration
Android:
Copy `android/mipmap-*` and `android/drawable` into `app/src/main/res/`.

Windows:
Use `windows/PeoYame.ico` for desktop icon and `windows/assets/*` for package logo fields.

Web:
Copy `web/*` into your public/static assets directory and reference the appropriate sizes in your manifest/favicon setup.

## Note on vector artwork
The supplied SVG is a valid SVG container embedding the approved artwork. It is not a path-native vector reconstruction. For production printing and arbitrary scaling, a true vector redraw is recommended.
