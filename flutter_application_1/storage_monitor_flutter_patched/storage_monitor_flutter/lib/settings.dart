import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

const _key = 'api_base_url';

Future<String> loadBaseUrl() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? defaultApiBaseUrl;
  } catch (_) {
    return defaultApiBaseUrl;
  }
}

Future<void> saveBaseUrl(String url) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url);
  } catch (_) {}
}

/// Adds http:// if missing and removes trailing slashes.
String normalizeBaseUrl(String input) {
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
