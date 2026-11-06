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
    final previousUrl = _api.baseUrl;
    _api.baseUrl = normalizeApiBaseUrl(value);
    if (previousUrl != _api.baseUrl && _timer != null) {
      // Release the old stream so its reconnect loop attaches to the new PC.
      final disconnect = _eventDisconnect;
      if (disconnect != null && !disconnect.isCompleted) {
        disconnect.complete();
      }
      unawaited(_refresh());
    }
  }

  StatusResponse? status;
  List<Alert> alerts = const [];
  List<Reading> history = const [];
  List<TrendPoint> trends = const [];
  String trendRange = '24h';
  String? trendError;
  bool isLoading = true;
  bool isChangingHarvest = false;
  List<Threshold> crops = const [];
  String? errorMessage;
  bool isBackendConnected = false;

  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  Completer<void>? _eventDisconnect;
  bool _disposed = false;
  bool _connectingEvents = false;
  int _refreshGeneration = 0;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;

  void startPolling() {
    _timer?.cancel();
    unawaited(loadCrops());
    _refresh();
    _connectEvents();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _connectEvents() async {
    if (_connectingEvents || _disposed) return;
    _connectingEvents = true;
    var retrySeconds = 2;
    try {
      while (!_disposed) {
        StreamSubscription<Map<String, dynamic>>? subscription;
        var receivedEvent = false;
        final disconnected = Completer<void>();
        _eventDisconnect = disconnected;
        try {
          final stream = await _api.watchUpdates();
          if (_disposed) break;
          subscription = stream.listen(
            (event) {
              if (_disposed) return;
              receivedEvent = true;
              if (event['type'] == 'crops') unawaited(loadCrops());
              unawaited(_refresh());
            },
            onError: (Object _, StackTrace __) {
              if (!disconnected.isCompleted) disconnected.complete();
            },
            onDone: () {
              if (!disconnected.isCompleted) disconnected.complete();
            },
            cancelOnError: true,
          );
          _eventSubscription = subscription;
          await disconnected.future;
        } catch (_) {
          // The regular refresh remains available while the event stream reconnects.
        } finally {
          if (subscription != null) {
            await subscription.cancel();
            if (identical(_eventSubscription, subscription)) {
              _eventSubscription = null;
            }
          }
          if (identical(_eventDisconnect, disconnected)) {
            _eventDisconnect = null;
          }
        }
        if (!_disposed) {
          if (receivedEvent) retrySeconds = 2;
          await Future<void>.delayed(Duration(seconds: retrySeconds));
          retrySeconds = (retrySeconds * 2).clamp(2, 30).toInt();
        }
      }
    } finally {
      _connectingEvents = false;
    }
  }

  Future<void> loadCrops() async {
    try {
      crops = await _api.getCrops();
    } catch (_) {}
    if (!_disposed) notifyListeners();
  }

  Future<void> addCrop({
    required String name,
    required double minTemp,
    required double maxTemp,
    required double minHumidity,
    required double maxHumidity,
  }) async {
    final crop = await _api.addCrop(
      name: name,
      minTemp: minTemp,
      maxTemp: maxTemp,
      minHumidity: minHumidity,
      maxHumidity: maxHumidity,
    );
    crops = [
      ...crops.where(
        (item) => item.commodity.toLowerCase() != crop.commodity.toLowerCase(),
      ),
      crop,
    ];
    if (!_disposed) notifyListeners();
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
    } catch (_) {
      if (!_disposed) {
        errorMessage = 'Could not select $name. Check the backend connection.';
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
    if (_refreshInFlight) {
      // Coalesce timer ticks and manual refreshes instead of stacking HTTP
      // requests when the backend is slow or unreachable.
      _refreshQueued = true;
      return;
    }
    _refreshInFlight = true;
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
      isBackendConnected = true;
      errorMessage = null;
      await _loadTrends(notify: false);
    } catch (_) {
      if (_disposed || generation != _refreshGeneration) return;
      isBackendConnected = false;
      errorMessage =
          'Backend disconnected. Your last readings are saved on screen. Reconnecting automatically; check that the PC backend is running and your phone is on the same Wi-Fi.';
    } finally {
      _refreshInFlight = false;
      final shouldRefreshAgain = _refreshQueued && !_disposed;
      _refreshQueued = false;
      if (!_disposed && generation == _refreshGeneration) {
        isLoading = false;
        notifyListeners();
      }
      if (shouldRefreshAgain) unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    final disconnect = _eventDisconnect;
    if (disconnect != null && !disconnect.isCompleted) {
      disconnect.complete();
    }
    _eventSubscription?.cancel();
    _api.dispose();
    super.dispose();
  }
}
