import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiService {
  ApiService({String? baseUrl, http.Client? client})
    : baseUrl = normalizeApiBaseUrl(baseUrl ?? defaultApiBaseUrl),
      _client = client ?? http.Client();

  String baseUrl;
  String? authToken;
  bool isDemoMode = true;
  final http.Client _client;

  Map<String, String> get _authHeaders =>
      authToken == null ? const {} : {'Authorization': 'Bearer $authToken'};

  Future<void> checkConnection() async {
    final response = await _client
        .get(_uri('/api/health'))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'This address returned HTTP ${response.statusCode}.',
      );
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (result['status'] != 'ok') {
      throw const FormatException('This address is not a Peo Yame backend.');
    }
    isDemoMode = result['demoMode'] == true;
  }

  Future<Map<String, dynamic>> signInWithMobileQr({
    required String challenge,
  }) async {
    final response = await _client
        .post(
          _uri('/api/auth/mobile-qr'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'challenge': challenge}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    authToken = result['token'] as String;
    return result['farmer'] as Map<String, dynamic>;
  }

  Future<void> approveWebLoginQr(String challenge) async {
    final response = await _client
        .post(
          _uri('/api/account/web-login-qr/approve'),
          headers: {'Content-Type': 'application/json', ..._authHeaders},
          body: jsonEncode({'challenge': challenge}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
  }

  Future<Map<String, dynamic>> requestPhoneSignInCode({
    required String phone,
  }) async {
    final response = await _client
        .post(
          _uri('/api/auth/request-otp'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signInWithPhoneCode({
    required String phone,
    required String code,
  }) async {
    final response = await _client
        .post(
          _uri('/api/auth/verify-otp'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone, 'code': code}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    authToken = result['token'] as String;
    return result;
  }

  Future<Map<String, dynamic>> skipPhoneVerificationForDemo({
    required String phone,
  }) async {
    final response = await _client
        .post(
          _uri('/api/auth/demo/skip-verification'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    authToken = result['token'] as String;
    return result;
  }

  Future<Map<String, dynamic>> updateAccount({
    required String name,
    required String phone,
    required String email,
  }) async {
    final response = await _client
        .patch(
          _uri('/api/account'),
          headers: {'Content-Type': 'application/json', ..._authHeaders},
          body: jsonEncode({'name': name, 'phone': phone, 'email': email}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAccount() async {
    final response = await _client
        .get(_uri('/api/account'), headers: _authHeaders)
        .timeout(const Duration(seconds: 6));
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAuthenticatorStatus() async {
    final response = await _client
        .get(_uri('/api/account/authenticator'), headers: _authHeaders)
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setupAuthenticator() async {
    final response = await _client
        .post(
          _uri('/api/account/authenticator/setup'),
          headers: {'Content-Type': 'application/json', ..._authHeaders},
          body: '{}',
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> enableAuthenticator(String code) async {
    final response = await _client
        .post(
          _uri('/api/account/authenticator/enable'),
          headers: {'Content-Type': 'application/json', ..._authHeaders},
          body: jsonEncode({'code': code}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
  }

  Future<void> disableAuthenticator(String code) async {
    final response = await _client
        .post(
          _uri('/api/account/authenticator/disable'),
          headers: {'Content-Type': 'application/json', ..._authHeaders},
          body: jsonEncode({'code': code}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
  }

  Future<List<Map<String, dynamic>>> getFarmerCrops() async {
    final response = await _client
        .get(_uri('/api/farmer/crops'), headers: _authHeaders)
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<List<Threshold>> getCropOptions() => getCrops();

  Future<List<Map<String, dynamic>>> getAvailableFarmerSensors() async {
    final response = await _client
        .get(_uri('/api/farmer/available-sensors'), headers: _authHeaders)
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getFarmerSensors() async {
    final response = await _client
        .get(_uri('/api/farmer/sensors'), headers: _authHeaders)
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> addFarmerCropWithSensors({
    required String commodity,
    required String label,
    required List<String> sensorCodes,
  }) async {
    final response = await _client
        .post(
          _uri('/api/farmer/crop-setup'),
          headers: {'Content-Type': 'application/json', ..._authHeaders},
          body: jsonEncode({
            'commodity': commodity,
            'label': label,
            'sensorCodes': sensorCodes,
          }),
        )
        .timeout(const Duration(seconds: 12));
    _ensureOk(response);
  }

  Future<void> deleteFarmerCrop(int id) async {
    final response = await _client
        .delete(_uri('/api/farmer/crops/$id'), headers: _authHeaders)
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
  }

  Future<void> logout() async {
    final response = await _client
        .post(
          _uri('/api/auth/logout'),
          headers: {'Content-Type': 'application/json', ..._authHeaders},
          body: '{}',
        )
        .timeout(const Duration(seconds: 5));
    _ensureOk(response);
    authToken = null;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<StatusResponse> getStatus() async {
    final response = await _client
        .get(_uri('/api/status'))
        .timeout(const Duration(seconds: 4));
    _ensureOk(response);
    return StatusResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<Threshold>> getCrops() async {
    final response = await _client
        .get(_uri('/api/crops'))
        .timeout(const Duration(seconds: 5));
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((item) => Threshold.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Threshold> addCrop({
    required String name,
    required double minTemp,
    required double maxTemp,
    required double minHumidity,
    required double maxHumidity,
  }) async {
    final response = await _client
        .post(
          _uri('/api/crops'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'minTemp': minTemp,
            'maxTemp': maxTemp,
            'minHumidity': minHumidity,
            'maxHumidity': maxHumidity,
          }),
        )
        .timeout(const Duration(seconds: 6));
    _ensureOk(response);
    return Threshold.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<Alert>> getAlerts() async {
    final response = await _client
        .get(_uri('/api/alerts'))
        .timeout(const Duration(seconds: 4));
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((item) => Alert.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Reading>> getHistory({int limit = 20}) async {
    final response = await _client
        .get(_uri('/api/readings/history', {'limit': '$limit'}))
        .timeout(const Duration(seconds: 4));
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((item) => Reading.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TrendPoint>> getTrends({String range = '24h'}) async {
    final response = await _client
        .get(_uri('/api/readings/trends', {'range': range}))
        .timeout(const Duration(seconds: 5));
    _ensureOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final points = data['points'] as List<dynamic>;
    return points
        .map((item) => TrendPoint.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Stream<Map<String, dynamic>>> watchUpdates() async {
    final request = http.Request('GET', _uri('/api/events'))
      ..headers['Accept'] = 'text/event-stream';
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw Exception(
        'Realtime connection returned HTTP ${response.statusCode}',
      );
    }
    return response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data:'))
        .map(
          (line) =>
              jsonDecode(line.substring(5).trim()) as Map<String, dynamic>,
        );
  }

  Future<void> triggerDemoBreach() async {
    final response = await _client
        .post(
          _uri('/api/sim/breach'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'source': 'flutter'}),
        )
        .timeout(const Duration(seconds: 4));
    _ensureOk(response);
  }

  Future<StatusResponse> setCommodity(String name) async {
    final response = await _client
        .post(
          _uri('/api/commodity'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'source': 'flutter'}),
        )
        .timeout(const Duration(seconds: 5));
    _ensureOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return StatusResponse(
      latest: data['reading'] == null
          ? null
          : Reading.fromJson(data['reading'] as Map<String, dynamic>),
      threshold: Threshold.fromJson(data['threshold'] as Map<String, dynamic>),
      breached: false,
    );
  }

  Future<void> recordAction(
    String action, {
    Map<String, Object?> details = const {},
  }) async {
    final response = await _client
        .post(
          _uri('/api/actions'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': action,
            'source': 'flutter',
            'actor': 'Olerato.M',
            'details': details,
          }),
        )
        .timeout(const Duration(seconds: 4));
    _ensureOk(response);
  }

  Future<String> getActionLogMarkdown({String source = 'flutter'}) async {
    final response = await _client
        .get(
          _uri('/api/actions/export.md', {'source': source}),
          headers: const {'Accept': 'text/markdown'},
        )
        .timeout(const Duration(seconds: 5));
    _ensureOk(response);
    return response.body;
  }

  Future<String> getReadingsCsv({String source = 'flutter'}) async {
    final response = await _client
        .get(
          _uri('/api/readings/export.csv', {'source': source}),
          headers: const {'Accept': 'text/csv'},
        )
        .timeout(const Duration(seconds: 5));
    _ensureOk(response);
    return response.body;
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final message = body['error'];
        if (message is String && message.isNotEmpty) {
          throw Exception(message);
        }
      } on FormatException {
        // Use the status/body fallback for non-JSON errors.
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  void dispose() {
    _client.close();
  }
}
