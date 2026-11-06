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
    required this.onDeleteFarmerCrop,
    required this.onLogout,
    required this.onDestinationSelected,
    super.key,
  });

  final String name;
  final String phone;
  final Future<void> Function(String name) onEditName;
  final Future<List<Map<String, dynamic>>> Function() onLoadFarmerCrops;
  final Future<void> Function(int id) onDeleteFarmerCrop;
  final VoidCallback onLogout;
  final ValueChanged<int> onDestinationSelected;

  void _openCrops(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyCropsScreen(
          name: name,
          onLoadFarmerCrops: onLoadFarmerCrops,
          onDeleteFarmerCrop: onDeleteFarmerCrop,
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

  void _showDemoMessage(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is a design preview; it is not connected yet.'),
      ),
    );
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
                            'Farmer account · Demo profile',
                            style: TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: _CountSummary(
                          value: '2',
                          label: 'Crops in storage',
                        ),
                      ),
                      SizedBox(height: 42, child: VerticalDivider(width: 1)),
                      Expanded(
                        child: _CountSummary(
                          value: '4',
                          label: 'Linked sensors',
                        ),
                      ),
                    ],
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
          subtitle: 'Maize · Sorghum · 4 sensors',
          onTap: () => _openCrops(context),
        ),
        const SizedBox(height: 8),
        _ActionCard(
          icon: Icons.sensors_outlined,
          title: 'Manage linked sensors',
          subtitle: '3 online · 1 offline · assign to crops',
          onTap: () => _openCrops(context),
        ),
        const SizedBox(height: 8),
        _ActionCard(
          icon: Icons.add_circle_outline,
          title: 'Link a sensor',
          subtitle: 'Add by sensor ID or QR code',
          onTap: () => _showDemoMessage(context, 'Sensor linking'),
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
          text: 'Demo profile and sensor links. No live connections.',
        ),
      ],
    );
  }
}

class MyCropsScreen extends StatefulWidget {
  const MyCropsScreen({
    required this.name,
    required this.onLoadFarmerCrops,
    required this.onDeleteFarmerCrop,
    required this.onDestinationSelected,
    super.key,
  });

  final String name;
  final Future<List<Map<String, dynamic>>> Function() onLoadFarmerCrops;
  final Future<void> Function(int id) onDeleteFarmerCrop;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<MyCropsScreen> createState() => _MyCropsScreenState();
}

class _MyCropsScreenState extends State<MyCropsScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All sensors';
  final Set<String> _deletedCrops = {};
  List<Map<String, dynamic>>? _farmerCrops;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadFarmerCrops();
  }

  Future<void> _loadFarmerCrops() async {
    try {
      final crops = await widget.onLoadFarmerCrops();
      if (mounted)
        setState(() {
          _farmerCrops = crops;
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

  static const _sensors = <_DemoSensor>[
    _DemoSensor(
      crop: 'Maize',
      initial: 'M',
      id: 'PY-001',
      store: 'Store A',
      temperature: '24.8°C',
      humidity: '66% RH',
      condition: 'Safe',
      freshness: 'Online · 2 min ago',
      online: true,
    ),
    _DemoSensor(
      crop: 'Maize',
      initial: 'M',
      id: 'PY-002',
      store: 'Store B',
      temperature: '25.6°C',
      humidity: '82% RH',
      condition: 'High humidity',
      freshness: 'Online · 5 min ago',
      online: true,
      attention: true,
    ),
    _DemoSensor(
      crop: 'Sorghum',
      initial: 'S',
      id: 'PY-003',
      store: 'Store C',
      temperature: '23.2°C',
      humidity: '58% RH',
      condition: 'Safe',
      freshness: 'Online · 2 min ago',
      online: true,
    ),
    _DemoSensor(
      crop: 'Sorghum',
      initial: 'S',
      id: 'PY-004',
      store: 'Store D',
      temperature: '22.7°C',
      humidity: '61% RH',
      condition: 'Offline',
      freshness: 'Last seen 3 h ago',
      online: false,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showLinkNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sensor linking is not connected in this demo.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_farmerCrops != null) return _buildAccountCrops();
    final query = _searchController.text.trim().toLowerCase();
    final visible = _sensors.where((sensor) {
      if (_deletedCrops.contains(sensor.crop)) return false;
      final matchesQuery =
          query.isEmpty ||
          '${sensor.crop} ${sensor.id} ${sensor.store}'.toLowerCase().contains(
            query,
          );
      final matchesFilter = switch (_filter) {
        'Attention' => sensor.attention,
        'Offline' => !sensor.online,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    final groups = <String, List<_DemoSensor>>{};
    for (final sensor in visible) {
      groups.putIfAbsent(sensor.crop, () => []).add(sensor);
    }

    return _DesignShell(
      title: 'My Crops',
      action: TextButton.icon(
        onPressed: _showLinkNotice,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add'),
      ),
      onBack: () => Navigator.of(context).maybePop(),
      selectedDestination: 3,
      onDestinationSelected: widget.onDestinationSelected,
      children: [
        _AccountScopeBanner(name: widget.name),
        const SizedBox(height: 8),
        const _DemoNotice(text: 'Demo readings · sensors are not connected'),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search crop, store or sensor ID',
            prefixIcon: const Icon(Icons.search, size: 19),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _border),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All sensors',
                selected: _filter == 'All sensors',
                onTap: () => setState(() => _filter = 'All sensors'),
              ),
              const SizedBox(width: 7),
              _FilterChip(
                label: 'Attention',
                count: '1',
                selected: _filter == 'Attention',
                onTap: () => setState(() => _filter = 'Attention'),
              ),
              const SizedBox(width: 7),
              _FilterChip(
                label: 'Offline',
                count: '1',
                selected: _filter == 'Offline',
                onTap: () => setState(() => _filter = 'Offline'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const _EmptySearch()
        else
          for (final entry in groups.entries) ...[
            _CropGroupCard(
              crop: entry.key,
              initial: entry.value.first.initial,
              sensors: entry.value,
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete this crop?'),
                    content: Text(
                      'Remove ${entry.key} and its displayed sensors from this demo account?',
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
                if (confirmed == true && mounted)
                  setState(() => _deletedCrops.add(entry.key));
              },
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 4),
        const Text(
          'Showing demo readings. Offline values are last known values, not current readings.',
          style: TextStyle(fontSize: 11, height: 1.35, color: _muted),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: _showLinkNotice,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Link another sensor'),
            style: TextButton.styleFrom(foregroundColor: _forest),
          ),
        ),
      ],
    );
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
      onBack: () => Navigator.of(context).maybePop(),
      selectedDestination: 3,
      onDestinationSelected: widget.onDestinationSelected,
      children: [
        _AccountScopeBanner(name: widget.name),
        const SizedBox(height: 10),
        if (_loadError != null)
          _DemoNotice(text: 'Could not load crop locations: $_loadError'),
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
          const _EmptySearch()
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

class _CountSummary extends StatelessWidget {
  const _CountSummary({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          height: 1,
          fontWeight: FontWeight.w800,
          color: _forest,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: _muted),
      ),
    ],
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final String label;
  final String? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : _muted;
    return Material(
      color: selected ? _forest : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? _forest : _border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Text(count!, style: TextStyle(fontSize: 9, color: foreground)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoSensor {
  const _DemoSensor({
    required this.crop,
    required this.initial,
    required this.id,
    required this.store,
    required this.temperature,
    required this.humidity,
    required this.condition,
    required this.freshness,
    required this.online,
    this.attention = false,
  });
  final String crop;
  final String initial;
  final String id;
  final String store;
  final String temperature;
  final String humidity;
  final String condition;
  final String freshness;
  final bool online;
  final bool attention;
}

class _CropGroupCard extends StatelessWidget {
  const _CropGroupCard({
    required this.crop,
    required this.initial,
    required this.sensors,
    required this.onDelete,
  });
  final String crop;
  final String initial;
  final List<_DemoSensor> sensors;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 6),
          child: Row(
            children: [
              Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _paleGreen,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  crop,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                '${sensors.length} sensors',
                style: const TextStyle(fontSize: 9, color: _muted),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right, size: 17, color: _muted),
            ],
          ),
        ),
        for (var index = 0; index < sensors.length; index++) ...[
          if (index > 0) const Divider(height: 1, indent: 11, endIndent: 11),
          _SensorRow(sensor: sensors[index]),
        ],
        const Divider(height: 1),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text('Delete crop'),
          ),
        ),
      ],
    ),
  );
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({required this.sensor});
  final _DemoSensor sensor;

  @override
  Widget build(BuildContext context) {
    final statusColor = sensor.attention
        ? _red
        : sensor.online
        ? _forest
        : _muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${sensor.id} · ${sensor.store}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                sensor.condition,
                style: TextStyle(
                  fontSize: 9,
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                sensor.temperature,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: sensor.attention ? _red : _ink,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '· ${sensor.humidity}',
                style: TextStyle(
                  fontSize: 10,
                  color: sensor.attention ? _red : _muted,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.circle,
                size: 6,
                color: sensor.online ? const Color(0xFF46A56A) : _muted,
              ),
              const SizedBox(width: 4),
              Text(
                sensor.freshness,
                style: const TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
