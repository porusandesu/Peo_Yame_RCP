import 'package:flutter/material.dart' hide Threshold;

import 'api_service.dart';
import 'models.dart';

const _forest = Color(0xFF176B4A);
const _muted = Color(0xFF65776F);

class FarmerLocationsPanel extends StatefulWidget {
  const FarmerLocationsPanel({
    required this.baseUrl,
    required this.token,
    required this.crops,
    required this.accountRevision,
    super.key,
  });

  final String baseUrl;
  final String token;
  final List<Threshold> crops;
  final int accountRevision;

  @override
  State<FarmerLocationsPanel> createState() => _FarmerLocationsPanelState();
}

class _FarmerLocationsPanelState extends State<FarmerLocationsPanel> {
  late ApiService _api;
  List<Map<String, dynamic>> _sites = const [];
  List<Map<String, dynamic>> _sensors = const [];
  List<Map<String, dynamic>> _available = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _loadRevision = 0;
  String _query = '';

  List<Map<String, dynamic>> get _filteredSites {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _sites;
    return _sites.where((site) {
      final id = site['id'];
      final linkedIds = _sensors.where((sensor) => sensor['siteId'] == id)
          .map((sensor) => sensor['sensorId']).join(' ');
      return '${site['commodity']} ${site['label']} $linkedIds'
          .toLowerCase().contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSensors {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _sensors;
    return _sensors.where((sensor) =>
      '${sensor['sensorId']} ${_sensorDescription(sensor)}'
          .toLowerCase().contains(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: widget.baseUrl, authToken: widget.token);
    _load();
  }

  @override
  void didUpdateWidget(covariant FarmerLocationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseUrl != widget.baseUrl ||
        oldWidget.token != widget.token ||
        oldWidget.accountRevision != widget.accountRevision) {
      final backendChanged =
          oldWidget.baseUrl != widget.baseUrl ||
          oldWidget.token != widget.token;
      if (backendChanged) {
        _api.dispose();
        _api = ApiService(baseUrl: widget.baseUrl, authToken: widget.token);
      }
      _loadRevision++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getFarmerCrops(),
        _api.getFarmerSensors(),
        _api.getAvailableFarmerSensors(),
      ]);
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _sites = results[0];
        _sensors = results[1];
        _available = results[2];
        _loading = false;
      });
    } catch (error) {
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _addLocation() async {
    var catalog = widget.crops;
    if (catalog.isEmpty) {
      try {
        catalog = await _api.getCrops();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load crop catalog: ${_message(error)}'),
            ),
          );
        }
        return;
      }
    }
    if (!mounted || catalog.isEmpty) return;
    var commodity = catalog.first.commodity;
    String? labelError;
    final labelController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add crop location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: commodity,
                decoration: const InputDecoration(labelText: 'Crop'),
                items: catalog
                    .map(
                      (crop) => DropdownMenuItem(
                        value: crop.commodity,
                        child: Text(crop.commodity),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => commodity = value);
                },
              ),
              TextField(
                controller: labelController,
                autofocus: true,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: 'Location name',
                  hintText: 'e.g. Main store',
                  errorText: labelError,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final label = labelController.text.trim();
                if (label.length < 2) {
                  setDialogState(
                    () => labelError = 'Enter at least 2 characters.',
                  );
                  return;
                }
                labelError = null;
                Navigator.pop(dialogContext, label);
              },
              child: const Text('Save location'),
            ),
          ],
        ),
      ),
    );
    labelController.dispose();
    if (result == null || !mounted) return;
    await _perform(
      () => _api.addFarmerCrop(commodity: commodity, label: result),
    );
  }

  Future<void> _linkSensor() async {
    if (_available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No unlinked sensors with real readings are available yet.',
          ),
        ),
      );
      return;
    }
    String sensorId = _available.first['sensorId'] as String;
    int? siteId;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Link a sensor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: sensorId,
                decoration: const InputDecoration(labelText: 'Detected sensor'),
                items: _available.map((sensor) {
                  final id = sensor['sensorId'] as String;
                  return DropdownMenuItem(value: id, child: Text(id));
                }).toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => sensorId = value);
                },
              ),
              DropdownButtonFormField<int?>(
                value: siteId,
                hint: const Text('No location yet'),
                decoration: const InputDecoration(labelText: 'Crop location'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('No location yet'),
                  ),
                  ..._sites.map(
                    (site) => DropdownMenuItem<int?>(
                      value: site['id'] as int,
                      child: Text(site['label'] as String),
                    ),
                  ),
                ],
                onChanged: (value) => setDialogState(() => siteId = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, sensorId),
              child: const Text('Link sensor'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _perform(
      () => _api.linkFarmerSensor(sensorId: result, siteId: siteId),
    );
  }

  Future<void> _deleteSite(Map<String, dynamic> site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete crop location?'),
        content: Text(
          'Remove ${site['label']} from this account? Linked sensors will be unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = site['id'] as int;
    await _perform(() => _api.deleteFarmerCrop(id));
  }

  Future<void> _unlinkSensor(String sensorId) async {
    await _perform(() => _api.unlinkFarmerSensor(sensorId));
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _AccountSectionTitle('Your crops & sensors'),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_sites.length} crop locations · ${_sensors.length} linked sensors',
                ),
              ),
              IconButton(
                onPressed: _loading || _saving ? null : _load,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Could not load account locations: $_error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ],
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (!_loading && _error == null) ...[
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search crop, location or sensor ID',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _addLocation,
          icon: const Icon(Icons.add),
          label: const Text('Add crop location'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : _linkSensor,
          icon: const Icon(Icons.sensors_outlined),
          label: const Text('Link a detected sensor'),
        ),
        const SizedBox(height: 8),
        if (_sites.isEmpty && _sensors.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No crop locations or linked sensors yet. Sensor IDs appear here only after the backend receives real sensor readings.',
              ),
            ),
          ),
        if (_filteredSites.isEmpty && _sites.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No crop locations or sensors match this search.'),
          ),
        ..._filteredSites.map((site) {
          final siteId = site['id'] as int;
          final linked = _sensors
              .where((sensor) => sensor['siteId'] == siteId)
              .toList();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.eco_outlined, color: _forest),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${site['label']} · ${site['commodity']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: _saving ? null : () => _deleteSite(site),
                        tooltip: 'Delete crop location',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${linked.length} linked sensor${linked.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
          );
        }),
        if (_filteredSensors.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _AccountSectionTitle('Linked sensors'),
          const SizedBox(height: 8),
          ..._filteredSensors.map((sensor) {
            final id = sensor['sensorId'] as String;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.sensors, color: _forest),
                title: Text(id),
                subtitle: Text(_sensorDescription(sensor)),
                trailing: IconButton(
                  onPressed: _saving ? null : () => _unlinkSensor(id),
                  tooltip: 'Unlink sensor',
                  icon: const Icon(Icons.link_off),
                ),
              ),
            );
          }),
        ],
        if (_available.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${_available.length} unlinked sensor${_available.length == 1 ? '' : 's'} with readings available.',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ],
    ],
  );

  String _sensorDescription(Map<String, dynamic> sensor) {
    final location =
        sensor['siteLabel'] as String? ?? 'No crop location assigned';
    final lastSeen = sensor['lastSeen'] as String?;
    if (lastSeen == null) return location;
    final parsed = DateTime.tryParse(lastSeen)?.toLocal();
    return '$location · last reading ${parsed?.toString() ?? lastSeen}';
  }
}

class _AccountSectionTitle extends StatelessWidget {
  const _AccountSectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  );
}
