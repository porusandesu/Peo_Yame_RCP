import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiService {
  ApiService({String? baseUrl, String? authToken, http.Client? client})
    : baseUrl = normalizeApiBaseUrl(baseUrl ?? defaultApiBaseUrl),
      authToken = authToken,
      _client = client ?? http.Client();

  String baseUrl;
  String? authToken;
  final http.Client _client;

  Map<String, String> get _authHeaders => authToken == null
      ? const {}
      : {'Authorization': 'Bearer $authToken'};

  Map<String, String> get _jsonAuthHeaders => {
    'Content-Type': 'application/json',
    ..._authHeaders,
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> checkConnection() async {
    final response = await _client.get(_uri('/api/health'))
        .timeout(const Duration(seconds: 6));
    _ensureOk(response);
    final health = jsonDecode(response.body) as Map<String, dynamic>;
    if (health['status'] != 'ok') throw const FormatException('This is not a Peo Yame backend.');
    return health;
  }

  Future<Map<String, dynamic>> registerFarmer({
    required String name,
    required String phone,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'phone': phone, 'password': password}),
    ).timeout(const Duration(seconds: 12));
    _ensureOk(response);
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    authToken = result['token'] as String;
    return result;
  }

  Future<Map<String, dynamic>> signIn({
    required String phone,
    required String password,
    String? authenticatorCode,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        if (authenticatorCode != null && authenticatorCode.isNotEmpty)
          'authenticatorCode': authenticatorCode,
      }),
    ).timeout(const Duration(seconds: 12));
    _ensureOk(response);
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    authToken = result['token'] as String;
    return result;
  }

  Future<Map<String, dynamic>> restoreSession(String token) async {
    authToken = token;
    final response = await _client.get(
      _uri('/api/auth/session'),
      headers: _authHeaders,
    ).timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> signOut() async {
    final response = await _client.post(
      _uri('/api/auth/logout'),
      headers: _jsonAuthHeaders,
      body: '{}',
    ).timeout(const Duration(seconds: 8));
    _ensureOk(response);
    authToken = null;
  }

  Future<Map<String, dynamic>> approveWebLoginQr(String challenge) async {
    final response = await _client.post(
      _uri('/api/auth/qr/web-challenge/$challenge/approve'),
      headers: _authHeaders,
    ).timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> exchangeMobileLoginQr(String challenge) async {
    final response = await _client.post(
      _uri('/api/auth/qr/mobile-exchange'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'challenge': challenge}),
    ).timeout(const Duration(seconds: 8));
    _ensureOk(response);
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    authToken = result['token'] as String;
    return result;
  }

  Future<Map<String, dynamic>> createMobileLoginQr() async {
    final response = await _client.post(
      _uri('/api/auth/qr/mobile-challenge'),
      headers: _authHeaders,
    ).timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setupAuthenticator() async {
    final response = await _client.post(
      _uri('/api/account/authenticator/setup'),
      headers: _authHeaders,
    ).timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> enableAuthenticator(String code) async {
    final response = await _client.post(
      _uri('/api/account/authenticator/enable'),
      headers: _jsonAuthHeaders,
      body: jsonEncode({'code': code}),
    ).timeout(const Duration(seconds: 8));
    _ensureOk(response);
  }

  Future<List<Map<String, dynamic>>> getFarmerCrops() async {
    final response = await _client.get(_uri('/api/farmer/crops'), headers: _authHeaders)
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getFarmerSensors() async {
    final response = await _client.get(_uri('/api/farmer/sensors'), headers: _authHeaders)
        .timeout(const Duration(seconds: 8));
    _ensureOk(response);
    return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> addFarmerCrop({required String commodity, required String label}) async {
    final response = await _client.post(
      _uri('/api/farmer/crops'),
      headers: _jsonAuthHeaders,
      body: jsonEncode({'commodity': commodity, 'label': label}),
    ).timeout(const Duration(seconds: 8));
    _ensureOk(response);
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

  Future<void> acknowledgeAlert(int id) async {
    final response = await _client.post(
      _uri('/api/alerts/$id/acknowledge'),
      headers: _jsonAuthHeaders,
      body: '{}',
    ).timeout(const Duration(seconds: 5));
    _ensureOk(response);
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
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  void dispose() {
    _client.close();
  }
}
