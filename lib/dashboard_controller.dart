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
  List<Map<String, dynamic>> smsLog = const [];
  List<Reading> history = const [];
  List<TrendPoint> trends = const [];
  String trendRange = '24h';
  String? trendError;
  bool isLoading = true;
  bool isTriggering = false;
  bool isChangingHarvest = false;
  bool demoMode = false;
  List<Threshold> crops = const [];
  String? errorMessage;
  DateTime? lastSuccessfulAt;
  bool get isOffline => _consecutiveFailures >= _offlineFailureThreshold;

  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  Completer<void>? _eventDisconnect;
  bool _disposed = false;
  bool _connectingEvents = false;
  int farmerAccountRevision = 0;
  int _refreshGeneration = 0;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  int _consecutiveFailures = 0;
  int _eventReconnectDelaySeconds = 2;
  static const int _offlineFailureThreshold = 2;
  static const int _maxEventReconnectDelaySeconds = 30;

  void startPolling({required bool demoMode}) {
    _timer?.cancel();
    this.demoMode = demoMode;
    _consecutiveFailures = 0;
    _eventReconnectDelaySeconds = 2;
    _refresh();
    _connectEvents();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _connectEvents() async {
    if (_connectingEvents || _disposed) return;
    _connectingEvents = true;
    try {
      while (!_disposed) {
        StreamSubscription<Map<String, dynamic>>? subscription;
        final disconnected = Completer<void>();
        _eventDisconnect = disconnected;
        var connected = false;
        try {
          final stream = await _api.watchUpdates();
          if (_disposed) break;
          connected = true;
          _eventReconnectDelaySeconds = 2;
          subscription = stream.listen(
            (event) {
              if (_disposed) return;
              if (event['type'] == 'crops') unawaited(loadCrops());
              if (event['type'] == 'account') {
                farmerAccountRevision++;
                notifyListeners();
              }
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
          if (!connected) {
            _eventReconnectDelaySeconds = (_eventReconnectDelaySeconds * 2)
                .clamp(2, _maxEventReconnectDelaySeconds);
          }
          await Future<void>.delayed(
            Duration(seconds: _eventReconnectDelaySeconds),
          );
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
        _api.getSmsLog().catchError((_) => smsLog),
        _api.getHistory(limit: 20),
      ]);

      if (_disposed || generation != _refreshGeneration) return;

      status = results[0] as StatusResponse;
      alerts = results[1] as List<Alert>;
      smsLog = results[2] as List<Map<String, dynamic>>;
      history = results[3] as List<Reading>;
      _consecutiveFailures = 0;
      lastSuccessfulAt = DateTime.now();
      errorMessage = null;
      await _loadTrends(notify: false);
    } catch (_) {
      if (_disposed || generation != _refreshGeneration) return;
      _consecutiveFailures += 1;
      // Tolerate one missed poll before treating the dashboard as offline so
      // brief network blips do not present stale readings as a hard outage.
      if (_consecutiveFailures >= _offlineFailureThreshold) {
        errorMessage =
            'No readings right now. Check your Wi-Fi and make sure the storage monitor is switched on.';
      }
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

  Future<void> triggerDemoBreach() async {
    if (isTriggering) return;
    isTriggering = true;
    notifyListeners();
    try {
      await _api.triggerDemoBreach();
      await _refresh();
    } catch (_) {
      if (_disposed) return;
      errorMessage =
          'The demo alert could not be sent. Check your Wi-Fi and try again.';
      isLoading = false;
    } finally {
      if (!_disposed) {
        isTriggering = false;
        notifyListeners();
      }
    }
  }

  Future<void> acknowledgeAlert(int id) async {
    try {
      await _api.acknowledgeAlert(id);
      await _refresh();
    } catch (_) {
      if (_disposed) return;
      errorMessage = 'Could not update this alert. Check the connection and try again.';
      notifyListeners();
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
