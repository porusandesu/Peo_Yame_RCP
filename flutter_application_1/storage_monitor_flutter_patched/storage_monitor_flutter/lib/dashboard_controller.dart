import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'models.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  StatusResponse? status;
  List<Alert> alerts = const [];
  List<Reading> history = const [];
  bool isLoading = true;
  String? errorMessage;

  String get baseUrl => _api.baseUrl;

  Future<void> setBaseUrl(String url) async {
    _api.baseUrl = url;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    await _refresh();
  }

  Timer? _timer;
  bool _disposed = false;

  void startPolling() {
    _timer?.cancel();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        _api.getStatus(),
        _api.getAlerts(),
        _api.getHistory(limit: 20),
      ]);

      if (_disposed) return;

      status = results[0] as StatusResponse;
      alerts = results[1] as List<Alert>;
      history = results[2] as List<Reading>;
      errorMessage = null;
    } catch (e) {
      if (_disposed) return;
      errorMessage =
          "Can't reach $baseUrl. Is the backend running and is the phone on the same Wi-Fi? Tap the gear icon to change the address. ($e)";
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }
}
