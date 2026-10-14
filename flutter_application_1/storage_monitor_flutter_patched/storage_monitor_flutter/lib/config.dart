/// Default API base URL for the storage-monitor demo backend.
///
/// You normally do NOT need to edit this: tap the gear icon in the app and
/// type the server address (e.g. http://192.168.1.42:3000). It is remembered.
///
/// - Android emulator: `http://10.0.2.2:3000` (maps to the host machine).
/// - Physical phone on the same Wi-Fi: your laptop's LAN IP (`hostname -I`).
///
/// A different default can be baked in at build time:
///   flutter build apk --dart-define=API_BASE_URL=http://192.168.1.42:3000
const String defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
