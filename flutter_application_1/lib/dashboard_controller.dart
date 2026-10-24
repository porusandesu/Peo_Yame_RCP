import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'config.dart';
import 'models.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  String get baseUrl => _api.baseUrl;

  void setBaseUrl(String value) {
    _api.baseUrl = normalizeApiBaseUrl(value);
  }

  StatusResponse? status;
  List<Alert> alerts = const [];
  List<Reading> history = const [];
  List<TrendPoint> trends = const [];
  String trendRange = '24h';
  String? trendError;
  bool isLoading = true;
  bool isTriggering = false;
  bool isChangingHarvest = false;
  String? errorMessage;

  Timer? _timer;
  bool _disposed = false;
  int _refreshGeneration = 0;

  void startPolling() {
    _timer?.cancel();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  Future<void> refresh() {
    recordAction('Manual refresh');
    return _refresh();
  }

  void recordAction(String action, {Map<String, Object?> details = const {}}) {
    unawaited(_api.recordAction(action, details: details).catchError((_) {}));
  }

  Future<String> exportActionLog() => _api.getActionLogMarkdown();

  Future<String> exportReadingsCsv() => _api.getReadingsCsv();

  Future<void> setTrendRange(String range) async {
    if (range == trendRange) return;
    trendRange = range;
    recordAction('Changed trend range', details: {'range': range});
    await _loadTrends();
  }

  Future<void> setHarvest(String name) async {
    if (isChangingHarvest) return;
    isChangingHarvest = true;
    // Ignore polls that began before (or while) the harvest change was sent.
    _refreshGeneration++;
    notifyListeners();
    try {
      final updatedStatus = await _api.setCommodity(name);
      if (_disposed) return;
      status = updatedStatus;
      errorMessage = null;
      _refreshGeneration++;
      notifyListeners();
      await _refresh();
    } catch (e) {
      if (!_disposed) {
        errorMessage = 'Could not select $name at $baseUrl. ($e)';
      }
    } finally {
      if (!_disposed) {
        isChangingHarvest = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadTrends({bool notify = true}) async {
    final range = trendRange;
    try {
      final points = await _api.getTrends(range: range);
      if (_disposed || range != trendRange) return;
      trends = points;
      trendError = null;
    } catch (_) {
      if (_disposed || range != trendRange) return;
      trendError = 'Trend history unavailable';
    }
    if (notify && !_disposed) notifyListeners();
  }

  Future<void> _refresh() async {
    final generation = _refreshGeneration;
    try {
      final results = await Future.wait([
        _api.getStatus(),
        _api.getAlerts(),
        _api.getHistory(limit: 20),
      ]);

      if (_disposed || generation != _refreshGeneration) return;

      status = results[0] as StatusResponse;
      alerts = results[1] as List<Alert>;
      history = results[2] as List<Reading>;
      errorMessage = null;
      await _loadTrends(notify: false);
    } catch (e) {
      if (_disposed || generation != _refreshGeneration) return;
      errorMessage =
          "Can't reach $baseUrl. Check that the backend is running and this device is on the same Wi-Fi. ($e)";
    } finally {
      if (!_disposed && generation == _refreshGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> triggerDemoBreach() async {
    if (isTriggering) return;
    isTriggering = true;
    notifyListeners();
    try {
      await _api.triggerDemoBreach();
      await _refresh();
    } catch (e) {
      if (_disposed) return;
      errorMessage = 'Could not trigger the demo breach at $baseUrl. ($e)';
      isLoading = false;
    } finally {
      if (!_disposed) {
        isTriggering = false;
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
