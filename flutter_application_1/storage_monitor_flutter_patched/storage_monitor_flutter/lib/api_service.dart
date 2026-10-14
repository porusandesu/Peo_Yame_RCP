import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiService {
  ApiService({this.baseUrl = defaultApiBaseUrl, http.Client? client})
      : _client = client ?? http.Client();

  String baseUrl;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<StatusResponse> getStatus() async {
    final response = await _client.get(_uri('/api/status'));
    _ensureOk(response);
    return StatusResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<Alert>> getAlerts() async {
    final response = await _client.get(_uri('/api/alerts'));
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((item) => Alert.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Reading>> getHistory({int limit = 20}) async {
    final response = await _client.get(
      _uri('/api/readings/history', {'limit': '$limit'}),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((item) => Reading.fromJson(item as Map<String, dynamic>))
        .toList();
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
