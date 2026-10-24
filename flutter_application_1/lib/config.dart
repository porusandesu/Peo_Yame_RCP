/// Emulator default. A physical phone can use the gear menu to enter the PC's
/// Wi-Fi address. A build-time override is also supported.
const String defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

const String apiBaseUrlPreferenceKey = 'storage_monitor_api_base_url';

String normalizeApiBaseUrl(String input) {
  var url = input.trim();
  if (url.isEmpty) return defaultApiBaseUrl;
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'http://$url';
  }
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}
