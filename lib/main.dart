import 'dart:convert';

import 'package:flutter/material.dart' hide Threshold;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'config.dart';
import 'dashboard_controller.dart';
import 'models.dart';

const _forest = Color(0xFF174A38);
const _canvas = Color(0xFFEBF2EB);
const _ink = Color(0xFF1F2B24);

void main() => runApp(const StorageMonitorApp());

class StorageMonitorApp extends StatelessWidget {
  const StorageMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: _forest);
    return MaterialApp(
      title: 'Peo Yame',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: _canvas,
        useMaterial3: true,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _forest,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE0F0E3),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shadowColor: const Color(0x0A173C2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE0E8E0)),
          ),
          margin: EdgeInsets.zero,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;
  String _baseUrl = defaultApiBaseUrl;
  int _selectedTab = 0;

  Future<void> _exportActionLog(BuildContext buttonContext) async {
    try {
      final markdown = await _controller.exportActionLog();
      if (!mounted) return;
      final renderBox = buttonContext.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(utf8.encode(markdown), mimeType: 'text/markdown'),
          ],
          fileNameOverrides: const ['peo-yame-actions.md'],
          title: 'Peo Yame activity log',
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export activity log: $error')),
        );
      }
    }
  }

  Future<void> _exportReadingsCsv(BuildContext buttonContext) async {
    try {
      final csv = await _controller.exportReadingsCsv();
      if (!mounted) return;
      final renderBox = buttonContext.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv')],
          fileNameOverrides: const ['peo-yame-readings.csv'],
          title: 'Peo Yame sensor data for Excel',
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export sensor data: $error')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = DashboardController();
    _loadSavedAddress();
  }

  Future<void> _loadSavedAddress() async {
    var address = defaultApiBaseUrl;
    try {
      final preferences = await SharedPreferences.getInstance();
      address = preferences.getString(apiBaseUrlPreferenceKey) ?? address;
    } catch (_) {
      // Keep the default address if preferences are unavailable.
    }
    if (!mounted) return;
    _baseUrl = normalizeApiBaseUrl(address);
    _controller.setBaseUrl(_baseUrl);
    _controller.startPolling();
  }

  Future<void> _editServerAddress() async {
    final textController = TextEditingController(text: _baseUrl);
    var validationMessage = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Backend address'),
          content: TextField(
            controller: textController,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: '192.168.1.42:3000',
              helperText: 'Enter the PC Wi-Fi address and port 3000.',
              errorText: validationMessage.isEmpty ? null : validationMessage,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final address = normalizeApiBaseUrl(textController.text);
                final uri = Uri.tryParse(address);
                if (uri == null ||
                    uri.host.isEmpty ||
                    (uri.scheme != 'http' && uri.scheme != 'https')) {
                  setDialogState(() {
                    validationMessage =
                        'Enter an address such as 192.168.1.42:3000.';
                  });
                  return;
                }
                Navigator.pop(dialogContext, address);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    textController.dispose();

    if (result == null || !mounted) return;
    final address = normalizeApiBaseUrl(result);
    setState(() {
      _baseUrl = address;
      _controller.setBaseUrl(address);
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(apiBaseUrlPreferenceKey, address);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address saved for this session only.')),
        );
      }
    }
    _controller.recordAction('Updated backend address');
    await _controller.refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final connected =
            _controller.status != null && _controller.errorMessage == null;
        final status = _controller.status;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: _forest,
            elevation: 0,
            titleSpacing: 20,
            title: const Row(
              children: [
                _BrandMark(size: 34),
                SizedBox(width: 10),
                Text('Peo Yame', style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            actions: [
              _ConnectionPill(connected: connected),
              IconButton(
                onPressed: _controller.refresh,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _controller.refresh,
            child: _tabBody(status),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) =>
                setState(() => _selectedTab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.show_chart_rounded),
                label: 'Trends',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none_rounded),
                selectedIcon: Icon(Icons.notifications_rounded),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabBody(StatusResponse? status) {
    final children = switch (_selectedTab) {
      0 => _homeContent(status),
      1 => _trendsContent(),
      2 => _alertsContent(status),
      _ => _settingsContent(status),
    };
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        if (_controller.errorMessage != null) ...[
          _ErrorBanner(message: _controller.errorMessage!),
          const SizedBox(height: 12),
        ],
        if (_controller.isLoading && status == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ...children,
      ],
    );
  }

  List<Widget> _homeContent(StatusResponse? status) => [
    const _FarmerGreeting(),
    const SizedBox(height: 16),
    if (status != null) ...[
      _StatusHero(status: status),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _MetricCard(
              title: 'Temperature',
              value: status.latest == null
                  ? '—'
                  : '${status.latest!.temperature.toStringAsFixed(1)}°',
              unit: 'Celsius',
              min: status.threshold.minTemp,
              max: status.threshold.maxTemp,
              current: status.latest?.temperature,
              icon: Icons.thermostat_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              title: 'Humidity',
              value: status.latest == null
                  ? '—'
                  : '${status.latest!.humidity.toStringAsFixed(0)}%',
              unit: 'Relative humidity',
              min: status.threshold.minHumidity,
              max: status.threshold.maxHumidity,
              current: status.latest?.humidity,
              icon: Icons.water_drop_outlined,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _HarvestCard(
        status: status,
        isChanging: _controller.isChangingHarvest,
        onChanged: _controller.setHarvest,
      ),
      const SizedBox(height: 18),
      _SectionTitle(
        title: 'Conditions over time',
        trailing: _RangeSelector(
          selected: _controller.trendRange,
          onChanged: _controller.setTrendRange,
        ),
      ),
      const SizedBox(height: 8),
      _TrendCard(
        points: _controller.trends,
        error: _controller.trendError,
        range: _controller.trendRange,
      ),
      const SizedBox(height: 18),
    ],
    _SectionTitle(
      title: 'Recent readings',
      trailing: Text(
        '${_controller.history.length}',
        style: const TextStyle(color: Color(0xFF718078)),
      ),
    ),
    const SizedBox(height: 8),
    if (_controller.history.isEmpty)
      const _EmptyCard(
        icon: Icons.sensors_outlined,
        text: 'Readings will appear here when the monitor connects.',
      )
    else
      ..._controller.history.reversed
          .take(4)
          .map(
            (reading) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _ReadingTile(
                reading: reading,
                threshold: status?.threshold,
              ),
            ),
          ),
  ];

  List<Widget> _trendsContent() => [
    const _SectionTitle(title: 'Trends'),
    const SizedBox(height: 4),
    const Text(
      'Monitor your storage conditions',
      style: TextStyle(color: Color(0xFF718078), fontSize: 13),
    ),
    const SizedBox(height: 16),
    _SectionTitle(
      title: 'Temperature & humidity',
      trailing: _RangeSelector(
        selected: _controller.trendRange,
        onChanged: _controller.setTrendRange,
      ),
    ),
    const SizedBox(height: 10),
    _TrendCard(
      points: _controller.trends,
      error: _controller.trendError,
      range: _controller.trendRange,
    ),
    const SizedBox(height: 18),
    const _SectionTitle(title: 'Recent readings'),
    const SizedBox(height: 8),
    if (_controller.history.isEmpty)
      const _EmptyCard(
        icon: Icons.sensors_outlined,
        text: 'Readings will appear here when the monitor connects.',
      )
    else
      ..._controller.history.reversed
          .take(20)
          .map(
            (reading) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _ReadingTile(
                reading: reading,
                threshold: _controller.status?.threshold,
              ),
            ),
          ),
  ];

  List<Widget> _alertsContent(StatusResponse? status) => [
    const _SectionTitle(title: 'Alerts'),
    const SizedBox(height: 4),
    const Text(
      'Storage alerts and notifications',
      style: TextStyle(color: Color(0xFF718078), fontSize: 13),
    ),
    const SizedBox(height: 14),
    if (status?.breached ?? false) ...[
      const _SectionTitle(title: 'Needs attention'),
      const SizedBox(height: 8),
      _StatusHero(status: status!),
      const SizedBox(height: 16),
    ],
    _SectionTitle(
      title: 'Alert history',
      trailing: _CountPill(count: _controller.alerts.length),
    ),
    const SizedBox(height: 8),
    if (_controller.alerts.isEmpty)
      const _EmptyCard(
        icon: Icons.notifications_none_rounded,
        text: 'No alerts yet. Your storage conditions look quiet.',
      )
    else
      ..._controller.alerts.map(
        (alert) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _AlertTile(alert: alert),
        ),
      ),
    const SizedBox(height: 16),
    Card(
      child: ListTile(
        leading: const Icon(
          Icons.notifications_active_outlined,
          color: _forest,
        ),
        title: const Text(
          'Test alert',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Generate a demo storage condition alert',
          style: TextStyle(fontSize: 12),
        ),
        trailing: _controller.isTriggering
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: _controller.isTriggering ? null : _controller.triggerDemoBreach,
      ),
    ),
  ];

  List<Widget> _settingsContent(StatusResponse? status) => [
    const _SectionTitle(title: 'Settings'),
    const SizedBox(height: 4),
    const Text(
      'Manage your storage monitor',
      style: TextStyle(color: Color(0xFF718078), fontSize: 13),
    ),
    const SizedBox(height: 16),
    const _SectionTitle(title: 'Harvest'),
    const SizedBox(height: 8),
    if (status != null)
      _HarvestCard(
        status: status,
        isChanging: _controller.isChangingHarvest,
        onChanged: _controller.setHarvest,
      ),
    const SizedBox(height: 16),
    const _SectionTitle(title: 'Connection'),
    const SizedBox(height: 8),
    Card(
      child: ListTile(
        leading: const Icon(Icons.wifi_rounded, color: _forest),
        title: const Text('Backend address'),
        subtitle: Text(_baseUrl, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: _editServerAddress,
      ),
    ),
    const SizedBox(height: 16),
    const _SectionTitle(title: 'Data'),
    const SizedBox(height: 8),
    Builder(
      builder: (buttonContext) => Card(
        child: ListTile(
          leading: const Icon(Icons.table_view_outlined, color: _forest),
          title: const Text('Export readings'),
          subtitle: const Text(
            'Download as CSV',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _exportReadingsCsv(buttonContext),
        ),
      ),
    ),
    Builder(
      builder: (buttonContext) => Card(
        child: ListTile(
          leading: const Icon(Icons.file_download_outlined, color: _forest),
          title: const Text('Export activity log'),
          subtitle: const Text(
            'Download as Markdown',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _exportActionLog(buttonContext),
        ),
      ),
    ),
    const SizedBox(height: 16),
    const _SectionTitle(title: 'About'),
    const SizedBox(height: 8),
    const _SimulationBanner(),
    const SizedBox(height: 8),
    const Card(
      child: ListTile(
        leading: Icon(Icons.eco_outlined, color: _forest),
        title: Text('Peo Yame'),
        subtitle: Text(
          'Storage Monitor · simulated readings',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ),
  ];
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? const Color(0xFF8DE0AE) : const Color(0xFFFFA5A5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            connected ? 'Status' : 'Offline',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _forest,
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: CustomPaint(painter: _BrandMarkPainter()),
  );
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 40;
    canvas.save();
    canvas.scale(scale);
    final gold = Paint()..color = const Color(0xFFF2C66D);
    final cream = Paint()..color = const Color(0xFFF8F6E9);
    final line = Paint()
      ..color = const Color(0xFFF8F6E9)
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 19, 24, 13),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF2F694F),
    );
    canvas.drawLine(const Offset(20, 28), const Offset(20, 9), line);
    for (var i = 0; i < 3; i++) {
      final y = 13.0 + i * 5;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(16, y), width: 7, height: 3.4),
        gold,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(24, y - 2), width: 7, height: 3.4),
        cream,
      );
    }
    canvas.drawLine(const Offset(12, 24), const Offset(28, 24), line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SimulationBanner extends StatelessWidget {
  const _SimulationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E5),
        border: Border.all(color: const Color(0xFFF0DCA7)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF8A6C27), size: 18),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Simulated readings · no physical sensor or SMS connected',
              style: TextStyle(color: Color(0xFF624D1C), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmerGreeting extends StatelessWidget {
  const _FarmerGreeting();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 21,
          backgroundColor: Color(0xFFE0EEE5),
          child: Text(
            'OM',
            style: TextStyle(color: _forest, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olerato.M',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'Your harvest at a glance',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF718078)),
              ),
            ],
          ),
        ),
        const Icon(Icons.eco_outlined, color: _forest),
      ],
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.status});

  final StatusResponse status;

  @override
  Widget build(BuildContext context) {
    final breached = status.breached;
    final latest = status.latest;
    final background = breached ? const Color(0xFF8E342E) : _forest;
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [background, Color.lerp(background, Colors.black, .16)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: .22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                breached ? Icons.warning_amber_rounded : Icons.check_circle,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  breached ? 'Attention needed' : 'Conditions are safe',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            latest == null
                ? 'Waiting for the first reading'
                : 'Last synced ${_relativeTime(latest.recordedAt)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (latest != null) ...[
            const SizedBox(height: 17),
            Row(
              children: [
                _HeroMetric(
                  label: 'Temperature',
                  value: '${latest.temperature.toStringAsFixed(1)}°C',
                  icon: Icons.thermostat_rounded,
                ),
                const SizedBox(width: 22),
                _HeroMetric(
                  label: 'Humidity',
                  value: '${latest.humidity.toStringAsFixed(1)}%',
                  icon: Icons.water_drop_outlined,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 19),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.current,
    required this.icon,
  });

  final String title;
  final String value;
  final String unit;
  final double min;
  final double max;
  final double? current;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 14, 13, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: _forest),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(fontSize: 10, color: Color(0xFF718078)),
            ),
            const SizedBox(height: 13),
            _RiskGauge(value: current, min: min, max: max),
            const SizedBox(height: 6),
            Text(
              'Safe ${_fmt(min)}–${_fmt(max)}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF718078)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskGauge extends StatelessWidget {
  const _RiskGauge({required this.value, required this.min, required this.max});

  final double? value;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    final midpoint = (min + max) / 2;
    final halfRange = (max - min) / 2;
    final risk = value == null
        ? .5
        : ((value! - midpoint).abs() / halfRange).clamp(0.0, 1.0).toDouble();
    return Column(
      children: [
        SizedBox(
          height: 12,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFD15B4E),
                        Color(0xFFE9B35F),
                        Color(0xFF56A873),
                        Color(0xFFE9B35F),
                        Color(0xFFD15B4E),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: (constraints.maxWidth * risk - 6)
                      .clamp(0.0, constraints.maxWidth - 12)
                      .toDouble(),
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF183A2C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'High',
              style: TextStyle(fontSize: 9, color: Color(0xFF718078)),
            ),
            Text(
              'Low',
              style: TextStyle(fontSize: 9, color: Color(0xFF718078)),
            ),
            Text(
              'High',
              style: TextStyle(fontSize: 9, color: Color(0xFF718078)),
            ),
          ],
        ),
      ],
    );
  }
}

class _HarvestCard extends StatelessWidget {
  const _HarvestCard({
    required this.status,
    required this.isChanging,
    required this.onChanged,
  });

  final StatusResponse status;
  final bool isChanging;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final latest = status.latest;
    final days = latest == null ? null : _estimateDays(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F3EA),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.grass_rounded, color: _forest),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Harvest',
                    style: TextStyle(fontSize: 11, color: Color(0xFF718078)),
                  ),
                  DropdownButton<String>(
                    value: status.threshold.commodity,
                    isDense: true,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    onChanged: isChanging
                        ? null
                        : (crop) {
                            if (crop != null) onChanged(crop);
                          },
                    items: const [
                      DropdownMenuItem(value: 'Maize', child: Text('Maize')),
                      DropdownMenuItem(value: 'Tomato', child: Text('Tomato')),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Storage estimate',
                  style: TextStyle(fontSize: 11, color: Color(0xFF718078)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isChanging) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      days == null ? 'Awaiting data' : '~$days days',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

int _estimateDays(StatusResponse status) {
  final t = status.threshold;
  final r = status.latest!;
  final tempRisk =
      ((r.temperature - (t.minTemp + t.maxTemp) / 2).abs() /
              ((t.maxTemp - t.minTemp) / 2))
          .clamp(0.0, 1.0);
  final humidityRisk =
      ((r.humidity - (t.minHumidity + t.maxHumidity) / 2).abs() /
              ((t.maxHumidity - t.minHumidity) / 2))
          .clamp(0.0, 1.0);
  final risk = tempRisk > humidityRisk ? tempRisk : humidityRisk;
  if (status.breached) return 7;
  if (risk > .8) return 30;
  if (risk > .55) return 60;
  if (risk > .3) return 120;
  return 180;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _ranges = {'24h': '24H', 'month': '1M', '3months': '3M'};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEE9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _ranges.entries.map((entry) {
          final active = entry.key == selected;
          return GestureDetector(
            onTap: () => onChanged(entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: active
                    ? const [BoxShadow(color: Color(0x14000000), blurRadius: 4)]
                    : null,
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active ? _forest : const Color(0xFF718078),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.points,
    required this.error,
    required this.range,
  });

  final List<TrendPoint> points;
  final String? error;
  final String range;

  @override
  Widget build(BuildContext context) {
    final sampled = _samplePoints(points, 220);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Legend(color: Color(0xFF248257), text: 'Temperature °C'),
                _Legend(color: Color(0xFF4E81CE), text: 'Humidity %'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: sampled.isEmpty
                  ? Center(
                      child: Text(
                        error ?? 'Collecting trend data…',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF718078),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : CustomPaint(painter: _TrendPainter(points: sampled)),
            ),
            const SizedBox(height: 4),
            Text(
              '${_rangeLabel(range)} · includes a stable simulated 24-hour baseline. Newer readings are live simulation data; older month history is collected after startup.',
              style: const TextStyle(fontSize: 10, color: Color(0xFF718078)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.points});

  final List<TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final chart = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFFE8EEE9)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    if (points.length < 2) {
      final dot = Paint()..color = const Color(0xFF248257);
      canvas.drawCircle(Offset(chart.left, chart.center.dy), 4, dot);
      return;
    }
    _drawSeries(
      canvas,
      chart,
      points.map((p) => p.temperature).toList(),
      const Color(0xFF248257),
    );
    _drawSeries(
      canvas,
      chart,
      points.map((p) => p.humidity).toList(),
      const Color(0xFF4E81CE),
    );
  }

  void _drawSeries(Canvas canvas, Rect rect, List<double> values, Color color) {
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final spread = maximum - minimum;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = rect.left + rect.width * i / (values.length - 1);
      final normalized = spread == 0 ? .5 : (values[i] - minimum) / spread;
      final y = rect.bottom - rect.height * normalized;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

List<TrendPoint> _samplePoints(List<TrendPoint> points, int maximum) {
  if (points.length <= maximum) return points;
  final step = (points.length - 1) / (maximum - 1);
  return List.generate(maximum, (index) => points[(index * step).round()]);
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF53645B)),
      ),
    ],
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE8EEE9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: _forest,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEAE7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.notifications_active_outlined,
            color: Color(0xFFAA4037),
            size: 19,
          ),
        ),
        title: Text(
          alert.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _formatDate(alert.sentAt),
          style: const TextStyle(fontSize: 10),
        ),
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.reading, required this.threshold});

  final Reading reading;
  final Threshold? threshold;

  @override
  Widget build(BuildContext context) {
    final breached =
        threshold != null &&
        (reading.temperature < threshold!.minTemp ||
            reading.temperature > threshold!.maxTemp ||
            reading.humidity < threshold!.minHumidity ||
            reading.humidity > threshold!.maxHumidity);
    return Card(
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Icon(
          breached ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          color: breached ? const Color(0xFFAA4037) : _forest,
          size: 20,
        ),
        title: Text(
          '${reading.temperature.toStringAsFixed(1)}°C   ·   ${reading.humidity.toStringAsFixed(1)}% RH',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _formatDate(reading.recordedAt),
          style: const TextStyle(fontSize: 10),
        ),
        trailing: Text(
          breached ? 'Alert' : 'Safe',
          style: TextStyle(
            fontSize: 10,
            color: breached ? const Color(0xFFAA4037) : _forest,
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF718078)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF718078)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEAE7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFF8E342E), fontSize: 12),
    ),
  );
}

String _fmt(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _rangeLabel(String range) => switch (range) {
  'month' => '1 month',
  '3months' => '3 months',
  _ => '24 hours',
};

String _formatDate(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return raw;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]}, $hour:$minute';
}

String _relativeTime(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return 'just now';
  final difference = DateTime.now().difference(date);
  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  return '${difference.inDays} days ago';
}
