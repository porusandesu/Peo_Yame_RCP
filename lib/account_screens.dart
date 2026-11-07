import 'package:flutter/material.dart';

const _forest = Color(0xFF176B4A);
const _muted = Color(0xFF65776F);

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({
    required this.name,
    required this.email,
    required this.phone,
    required this.isDemo,
    required this.onLogout,
    required this.onDestinationSelected,
    super.key,
  });

  final String name;
  final String email;
  final String phone;
  final bool isDemo;
  final VoidCallback onLogout;
  final ValueChanged<int> onDestinationSelected;

  void _openCrops(BuildContext context) {
    Navigator.of(context).pop();
    onDestinationSelected(2);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(isDemo ? 'Shared demo profile' : 'Account'),
      backgroundColor: const Color(0xFF10251F),
      foregroundColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (isDemo) ...[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Shared Demo profile · no farmer account or sensor links are created.',
                style: TextStyle(color: _muted),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ProfileRow(icon: Icons.person_outline, label: 'Name', value: name),
                if (email.isNotEmpty) ...[
                  const Divider(height: 1),
                  _ProfileRow(icon: Icons.mail_outline, label: 'Email', value: email),
                ],
                if (phone.isNotEmpty) ...[
                  const Divider(height: 1),
                  _ProfileRow(icon: Icons.phone_outlined, label: 'Phone', value: phone),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.eco_outlined, color: _forest),
            title: const Text('My Crops'),
            subtitle: Text(isDemo
                ? 'Browse the shared catalog and indicative crop guidance.'
                : 'Browse crop monitoring bands and guidance.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openCrops(context),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sensors_outlined, color: _forest),
            title: const Text('Sensors'),
            subtitle: Text(isDemo
                ? 'No physical sensor links are saved in shared Demo mode.'
                : 'Sensor readings are shown as shared demo data; farmer-owned sensor management is not available in mobile yet.'),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: Icon(isDemo ? Icons.exit_to_app : Icons.logout),
          label: Text(isDemo ? 'Exit Demo mode' : 'Sign out'),
        ),
      ],
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, color: _forest, size: 20),
        const SizedBox(width: 12),
        SizedBox(width: 70, child: Text(label, style: const TextStyle(color: _muted, fontSize: 12))),
        Expanded(child: Text(value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}
