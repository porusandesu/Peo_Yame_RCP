import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiService {
  ApiService({String? baseUrl, http.Client? client})
    : baseUrl = normalizeApiBaseUrl(baseUrl ?? defaultApiBaseUrl),
      _client = client ?? http.Client();

  String baseUrl;
  final http.Client _client;

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

  Future<void> triggerDemoBreach() async {
    final response = await _client
        .post(_uri('/api/sim/breach'))
        .timeout(const Duration(seconds: 4));
    _ensureOk(response);
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
