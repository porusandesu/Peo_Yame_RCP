import 'package:flutter/material.dart';

const _forest = Color(0xFF176B4A);
const _ink = Color(0xFF172923);
const _canvas = Color(0xFFF8FAF8);
const _muted = Color(0xFF65776F);
const _border = Color(0xFFE2EAE4);
const _paleGreen = Color(0xFFE2F1E6);
const _amberBg = Color(0xFFFFF5DF);
const _amberBorder = Color(0xFFF1DDA7);
const _amberInk = Color(0xFF765D24);
const _red = Color(0xFFB84036);

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({
    required this.name,
    required this.phone,
    required this.onEditName,
    required this.onLoadFarmerCrops,
    required this.onLoadFarmerSensors,
    required this.onDeleteFarmerCrop,
    required this.onLoadCropOptions,
    required this.onLoadAvailableSensors,
    required this.onCreateCropSetup,
    required this.onLogout,
    required this.onDestinationSelected,
    super.key,
  });

  final String name;
  final String phone;
  final Future<void> Function(String name) onEditName;
  final Future<List<Map<String, dynamic>>> Function() onLoadFarmerCrops;
  final Future<List<Map<String, dynamic>>> Function() onLoadFarmerSensors;
  final Future<void> Function(int id) onDeleteFarmerCrop;
  final Future<List<String>> Function() onLoadCropOptions;
  final Future<List<Map<String, dynamic>>> Function() onLoadAvailableSensors;
  final Future<void> Function({
    required String commodity,
    required String label,
    required List<String> sensorCodes,
  })
  onCreateCropSetup;
  final VoidCallback onLogout;
  final ValueChanged<int> onDestinationSelected;

  void _openCrops(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyCropsScreen(
          name: name,
          onLoadFarmerCrops: onLoadFarmerCrops,
          onLoadFarmerSensors: onLoadFarmerSensors,
          onDeleteFarmerCrop: onDeleteFarmerCrop,
          onLoadCropOptions: onLoadCropOptions,
          onLoadAvailableSensors: onLoadAvailableSensors,
          onCreateCropSetup: onCreateCropSetup,
          onDestinationSelected: onDestinationSelected,
        ),
      ),
    );
  }

  Future<void> _editAccount(BuildContext context) async {
    final controller = TextEditingController(text: name);
    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit account'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Farmer name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updatedName == null || updatedName.isEmpty || !context.mounted) return;
    try {
      await onEditName(updatedName);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update account: $error')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DesignShell(
      title: 'Accounts',
      action: TextButton(
        onPressed: () => _editAccount(context),
        child: const Text('Edit'),
      ),
      onBack: () => Navigator.of(context).maybePop(),
      selectedDestination: 3,
      onDestinationSelected: onDestinationSelected,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _Avatar(
                      initial: name.isEmpty ? 'F' : name[0].toUpperCase(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            phone,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Farmer account · verified by one-time PIN',
                            style: TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Crop locations and sensor assignments are saved to this backend.',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _SectionHeading('Your crops & sensors'),
        const SizedBox(height: 8),
        _ActionCard(
          icon: Icons.spa_outlined,
          title: 'My Crops',
          subtitle: 'Saved field and storage locations',
          onTap: () => _openCrops(context),
        ),
        const SizedBox(height: 8),
        _ActionCard(
          icon: Icons.sensors_outlined,
          title: 'Manage linked sensors',
          subtitle: 'View the sensor IDs assigned to each crop',
          onTap: () => _openCrops(context),
        ),
        const SizedBox(height: 8),
        _ActionCard(
          icon: Icons.add_circle_outline,
          title: 'Link a sensor',
          subtitle: 'Choose connected sensors while setting up a crop',
          onTap: () => _openCrops(context),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 17),
            label: const Text('Sign out'),
            style: TextButton.styleFrom(foregroundColor: _forest),
          ),
        ),
        const SizedBox(height: 4),
        const _DemoNotice(
          text:
              'Sensors appear in setup after the backend receives a sensor reading. Device identity is currently based on the submitted sensor ID.',
        ),
      ],
    );
  }
}

class MyCropsScreen extends StatefulWidget {
  const MyCropsScreen({
    required this.name,
    required this.onLoadFarmerCrops,
    required this.onLoadFarmerSensors,
    required this.onDeleteFarmerCrop,
    required this.onLoadCropOptions,
    required this.onLoadAvailableSensors,
    required this.onCreateCropSetup,
    required this.onDestinationSelected,
    super.key,
  });

  final String name;
  final Future<List<Map<String, dynamic>>> Function() onLoadFarmerCrops;
  final Future<List<Map<String, dynamic>>> Function() onLoadFarmerSensors;
  final Future<void> Function(int id) onDeleteFarmerCrop;
  final Future<List<String>> Function() onLoadCropOptions;
  final Future<List<Map<String, dynamic>>> Function() onLoadAvailableSensors;
  final Future<void> Function({
    required String commodity,
    required String label,
    required List<String> sensorCodes,
  })
  onCreateCropSetup;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<MyCropsScreen> createState() => _MyCropsScreenState();
}

class _MyCropsScreenState extends State<MyCropsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>>? _farmerCrops;
  List<Map<String, dynamic>> _farmerSensors = const [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadFarmerCrops();
  }

  Future<void> _loadFarmerCrops() async {
    try {
      final crops = await widget.onLoadFarmerCrops();
      final sensors = await widget.onLoadFarmerSensors();
      if (mounted)
        setState(() {
          _farmerCrops = crops;
          _farmerSensors = sensors;
          _loadError = null;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _farmerCrops = [];
          _loadError = '$error';
        });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_farmerCrops == null) {
      return _DesignShell(
        title: 'My Crops',
        action: const SizedBox.shrink(),
        onBack: () => Navigator.of(context).popUntil((route) => route.isFirst),
        selectedDestination: 3,
        onDestinationSelected: widget.onDestinationSelected,
        children: const [
          Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }
    return _buildAccountCrops();
  }

  Widget _buildAccountCrops() {
    final query = _searchController.text.trim().toLowerCase();
    final crops = _farmerCrops!
        .where(
          (crop) => '${crop['commodity']} ${crop['label']}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
    return _DesignShell(
      title: 'My Crops',
      action: TextButton.icon(
        onPressed: _loadFarmerCrops,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Refresh'),
      ),
      onBack: () => Navigator.of(context).popUntil((route) => route.isFirst),
      selectedDestination: 3,
      onDestinationSelected: widget.onDestinationSelected,
      children: [
        _AccountScopeBanner(name: widget.name),
        const SizedBox(height: 10),
        if (_loadError != null)
          _DemoNotice(text: 'Could not load crop locations: $_loadError'),
        FilledButton.icon(
          onPressed: _showAddCropSetup,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add crop and connect sensors'),
          style: FilledButton.styleFrom(backgroundColor: _forest),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search crop or field name',
          ),
        ),
        const SizedBox(height: 10),
        if (crops.isEmpty)
          _farmerCrops!.isEmpty ? const _EmptyCrops() : const _EmptySearch()
        else
          for (final crop in crops)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.spa_outlined, color: _forest),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${crop['commodity']} · ${crop['label']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${crop['sensorCount'] ?? 0} linked sensors',
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                          if (_farmerSensors
                              .where(
                                (sensor) =>
                                    sensor['farmerCropId'] == crop['id'],
                              )
                              .isNotEmpty)
                            Text(
                              'IDs: ${_farmerSensors.where((sensor) => sensor['farmerCropId'] == crop['id']).map((sensor) => sensor['sensorCode']).join(', ')}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteCrop(crop),
                      icon: const Icon(Icons.delete_outline, size: 17),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: _red),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _deleteCrop(Map<String, dynamic> crop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete crop location?'),
        content: Text(
          'Delete ${crop['commodity']} · ${crop['label']} and unlink its sensors?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.onDeleteFarmerCrop((crop['id'] as num).toInt());
      await _loadFarmerCrops();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete crop: $error')),
        );
    }
  }

  Future<void> _showAddCropSetup() async {
    try {
      final crops = await widget.onLoadCropOptions();
      final sensors = await widget.onLoadAvailableSensors();
      if (!mounted) return;
      if (crops.isEmpty)
        throw Exception('No crops are configured in the backend yet.');
      final labelController = TextEditingController();
      var commodity = crops.first;
      var errorMessage = '';
      final selectedSensors = <String>{};
      final created = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Set up a crop and its sensors'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: commodity,
                      decoration: const InputDecoration(labelText: 'Crop'),
                      items: crops
                          .map(
                            (crop) => DropdownMenuItem(
                              value: crop,
                              child: Text(crop),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null)
                          setDialogState(() => commodity = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: labelController,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Field or storage name',
                        hintText: 'For example: North store',
                      ),
                    ),
                    const SizedBox(height: 6),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        selectedSensors.isEmpty
                            ? 'Choose connected backend sensors'
                            : '${selectedSensors.length} sensor${selectedSensors.length == 1 ? '' : 's'} selected',
                      ),
                      subtitle: Text(
                        selectedSensors.isEmpty
                            ? 'Select one or more sensor IDs'
                            : selectedSensors.join(', '),
                      ),
                      children: [
                        if (sensors.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(10),
                            child: _DemoNotice(
                              text:
                                  'No sensor has sent a reading to this backend yet. Once a sensor sends a reading, its ID appears here automatically.',
                            ),
                          ),
                        for (final sensor in sensors)
                          Builder(
                            builder: (context) {
                              final code = sensor['sensorCode'] as String;
                              final connected = sensor['connected'] == true;
                              final lastSeen = DateTime.tryParse(
                                '${sensor['lastSeen']}',
                              )?.toLocal();
                              return CheckboxListTile(
                                dense: true,
                                value: selectedSensors.contains(code),
                                onChanged: connected
                                    ? (selected) => setDialogState(() {
                                        if (selected == true) {
                                          selectedSensors.add(code);
                                        } else {
                                          selectedSensors.remove(code);
                                        }
                                      })
                                    : null,
                                title: Text(
                                  code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  connected
                                      ? 'Connected · last reading ${lastSeen == null ? 'recently' : _relativeSensorTime(lastSeen)}'
                                      : 'Offline · reconnect this sensor to assign it',
                                ),
                                secondary: Icon(
                                  connected
                                      ? Icons.sensors_rounded
                                      : Icons.sensors_off_rounded,
                                  color: connected ? _forest : _muted,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    if (errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: const TextStyle(color: _red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (labelController.text.trim().isEmpty) {
                    setDialogState(
                      () => errorMessage =
                          'Enter a name for this field or storage.',
                    );
                    return;
                  }
                  if (selectedSensors.isEmpty) {
                    setDialogState(
                      () => errorMessage =
                          'Choose at least one connected sensor.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Save crop setup'),
              ),
            ],
          ),
        ),
      );
      if (created == true && mounted) {
        await widget.onCreateCropSetup(
          commodity: commodity,
          label: labelController.text.trim(),
          sensorCodes: selectedSensors.toList(),
        );
        await _loadFarmerCrops();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crop location and sensor assignments saved.'),
            ),
          );
      }
      labelController.dispose();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set up crop and sensors: $error')),
        );
    }
  }
}

String _relativeSensorTime(DateTime timestamp) {
  final age = DateTime.now().difference(timestamp);
  if (age.inSeconds < 60) return 'just now';
  if (age.inMinutes < 60) return '${age.inMinutes} min ago';
  return '${age.inHours} hr ago';
}

class _DesignShell extends StatelessWidget {
  const _DesignShell({
    required this.title,
    required this.action,
    required this.onBack,
    required this.selectedDestination,
    required this.onDestinationSelected,
    required this.children,
  });

  final String title;
  final Widget action;
  final VoidCallback onBack;
  final int selectedDestination;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: SafeArea(
      child: Column(
        children: [
          const _BrandHeader(),
          SizedBox(
            height: 58,
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: const Icon(Icons.chevron_left, size: 24),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Align(alignment: Alignment.centerRight, child: action),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: children,
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selectedDestination,
      onDestinationSelected: (index) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        onDestinationSelected(index);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: 'Overview',
        ),
        NavigationDestination(
          icon: Icon(Icons.show_chart_rounded),
          label: 'Trends',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none_rounded),
          label: 'Alerts',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_rounded),
          label: 'Settings',
        ),
      ],
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    color: _canvas,
    child: Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: _paleGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.eco_rounded, size: 14, color: _forest),
        ),
        const SizedBox(width: 8),
        const Text(
          'Peo Yame',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _forest,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: _paleGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            'Demo',
            style: TextStyle(
              fontSize: 10,
              color: _forest,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: _paleGreen, shape: BoxShape.circle),
    child: Text(
      initial,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: _forest,
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: _ink,
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: _forest, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _muted, size: 19),
          ],
        ),
      ),
    ),
  );
}

class _AccountScopeBanner extends StatelessWidget {
  const _AccountScopeBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: _paleGreen,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(Icons.person_outline_rounded, size: 17, color: _forest),
        SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name’s account · 2 crops · 4 sensors',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '3 online · 1 offline · 1 needs attention',
                style: TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: _amberBg,
      border: Border.all(color: _amberBorder),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: _amberInk),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              height: 1.25,
              color: _amberInk,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Column(
      children: [
        Icon(Icons.search_off_rounded, color: _muted),
        SizedBox(height: 8),
        Text(
          'No sensors match this search.',
          style: TextStyle(fontSize: 12, color: _muted),
        ),
      ],
    ),
  );
}

class _EmptyCrops extends StatelessWidget {
  const _EmptyCrops();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      children: [
        Icon(Icons.spa_outlined, color: _muted),
        SizedBox(height: 8),
        Text(
          'No crop locations yet. Add a crop and connect at least one backend sensor.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: _muted),
        ),
      ],
    ),
  );
}
