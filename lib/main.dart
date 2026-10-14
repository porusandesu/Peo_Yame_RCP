import 'package:flutter/material.dart';

import 'dashboard_controller.dart';
import 'models.dart';

void main() {
  runApp(const StorageMonitorApp());
}

class StorageMonitorApp extends StatelessWidget {
  const StorageMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storage Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
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

  @override
  void initState() {
    super.initState();
    _controller = DashboardController()..startPolling();
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('Storage Monitor'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: RefreshIndicator(
            onRefresh: _controller.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_controller.errorMessage != null) ...[
                  _ErrorBanner(message: _controller.errorMessage!),
                  const SizedBox(height: 16),
                ],
                if (_controller.isLoading && _controller.status == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_controller.status != null) ...[
                  _StatusCard(status: _controller.status!),
                  const SizedBox(height: 24),
                ],
                Text(
                  'Recent Alerts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (_controller.alerts.isEmpty)
                  const Text('No alerts yet.', style: TextStyle(color: Colors.grey))
                else
                  ..._controller.alerts.take(10).map(
                        (alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AlertTile(alert: alert),
                        ),
                      ),
                const SizedBox(height: 24),
                Text(
                  'Recent Readings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (_controller.history.isEmpty)
                  const Text(
                    'No readings yet.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  ..._controller.history.map(
                    (reading) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ReadingTile(reading: reading),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFEBEE),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final StatusResponse status;

  @override
  Widget build(BuildContext context) {
    final breached = status.breached;
    final latest = status.latest;

    return Card(
      color: breached ? const Color(0xFFFFCDD2) : const Color(0xFFE8F5E9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              breached ? '⚠ Threshold breached' : '✓ Conditions normal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (latest != null) ...[
              Text('Temperature: ${latest.temperature.toStringAsFixed(1)}°C'),
              Text('Humidity: ${latest.humidity.toStringAsFixed(1)}%'),
              Text(
                'Recorded: ${latest.recordedAt}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Safe range for ${status.threshold.commodity}: '
              '${status.threshold.minTemp}-${status.threshold.maxTemp}°C, '
              '${status.threshold.minHumidity}-${status.threshold.maxHumidity}% RH',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.message, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              alert.sentAt,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.reading});

  final Reading reading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        title: Text(
          '${reading.temperature.toStringAsFixed(1)}°C  ·  '
          '${reading.humidity.toStringAsFixed(1)}% RH',
        ),
        subtitle: Text(reading.recordedAt),
      ),
    );
  }
}
