import 'dart:convert';

import 'package:flutter/material.dart' hide Threshold;
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'account_screens.dart';
import 'api_service.dart';
import 'config.dart';
import 'dashboard_controller.dart';
import 'models.dart';

const _forest = Color(0xFF176B4A);
const _header = Color(0xFF10251F);
const _canvas = Color(0xFFF3F7F3);
const _ink = Color(0xFF172923);

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
          backgroundColor: _header,
          foregroundColor: Colors.white,
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
          elevation: 1,
          shadowColor: const Color(0x10183326),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFDCE6DF)),
          ),
          margin: EdgeInsets.zero,
        ),
      ),
      home: const _AppGate(),
    );
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  final ApiService _authApi = ApiService();
  AccountInfo? _account;
  String? _pendingPhone;
  bool _loadingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _authApi.baseUrl = normalizeApiBaseUrl(
        preferences.getString(apiBaseUrlPreferenceKey) ?? defaultApiBaseUrl,
      );
      _authApi.authToken = preferences.getString('farmer_auth_token');
      if (_authApi.authToken != null) {
        final farmer = await _authApi.getAccount();
        _account = AccountInfo(
          name: farmer['name'] as String,
          email: '',
          phone: farmer['phone'] as String,
        );
      }
    } catch (_) {
      _authApi.authToken = null;
    }
    if (mounted) setState(() => _loadingSession = false);
  }

  void _requestCode(DemoSignInRequest request) {
    setState(() {
      _pendingPhone = request.phone;
    });
  }

  void _backToLogin() => setState(() => _pendingPhone = null);

  Future<void> _continueDemo(String code) async {
    final phone = _pendingPhone ?? '';
    final farmer = await _authApi.verifyOtp(phone: phone, code: code);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('farmer_auth_token', _authApi.authToken!);
    if (!mounted) return;
    setState(() {
      _account = AccountInfo(
        name: farmer['name'] as String,
        email: '',
        phone: farmer['phone'] as String,
      );
      _pendingPhone = null;
    });
  }

  Future<void> _logout() async {
    try {
      await _authApi.logout();
    } catch (_) {}
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('farmer_auth_token');
    if (mounted)
      setState(() {
        _account = null;
        _pendingPhone = null;
      });
  }

  Future<void> _editName(String name) async {
    final farmer = await _authApi.updateAccountName(name);
    if (!mounted) return;
    setState(
      () => _account = AccountInfo(
        name: farmer['name'] as String,
        email: '',
        phone: farmer['phone'] as String,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSession)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final account = _account;
    if (account != null) {
      return DashboardPage(
        account: account,
        onLogout: _logout,
        onEditName: _editName,
        onLoadFarmerCrops: _authApi.getFarmerCrops,
        onDeleteFarmerCrop: _authApi.deleteFarmerCrop,
      );
    }
    final pendingPhone = _pendingPhone;
    if (pendingPhone != null) {
      return OtpVerificationPage(
        phone: pendingPhone,
        onBack: _backToLogin,
        onContinue: _continueDemo,
        onScanQr: () async {
          final raw = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const _AuthQrScannerPage()),
          );
          if (raw == null) return;
          final data = jsonDecode(raw) as Map<String, dynamic>;
          if (data['type'] != 'peo-yame-auth' ||
              data['phone'] != pendingPhone ||
              data['backend'] is! String ||
              data['code'] is! String)
            throw Exception(
              'This sign-in QR code is invalid or for a different phone.',
            );
          final backend = Uri.tryParse(data['backend'] as String);
          if (backend == null ||
              backend.host.isEmpty ||
              !['http', 'https'].contains(backend.scheme))
            throw Exception('The sign-in QR has an invalid backend address.');
          _authApi.baseUrl = normalizeApiBaseUrl(data['backend'] as String);
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString(
            apiBaseUrlPreferenceKey,
            _authApi.baseUrl,
          );
          await _continueDemo(data['code'] as String);
        },
      );
    }
    return _LoginSplash(
      onScanSignInQr: () async {
        final raw = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const _AuthQrScannerPage()),
        );
        if (raw == null) return;
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final backend = Uri.tryParse(data['backend'] as String? ?? '');
        if (data['type'] != 'peo-yame-auth' ||
            backend == null ||
            backend.host.isEmpty ||
            data['phone'] is! String ||
            data['code'] is! String)
          throw Exception('This is not a valid sign-in QR code.');
        _pendingPhone = data['phone'] as String;
        _authApi.baseUrl = normalizeApiBaseUrl(data['backend'] as String);
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(apiBaseUrlPreferenceKey, _authApi.baseUrl);
        await _continueDemo(data['code'] as String);
      },
      onScanBackend: () async {
        final address = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const _BackendQrScannerPage()),
        );
        if (address == null) return;
        _authApi.baseUrl = normalizeApiBaseUrl(address);
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(apiBaseUrlPreferenceKey, _authApi.baseUrl);
      },
      onContinue: (request) async {
        try {
          _authApi.baseUrl = normalizeApiBaseUrl(
            (await SharedPreferences.getInstance()).getString(
                  apiBaseUrlPreferenceKey,
                ) ??
                defaultApiBaseUrl,
          );
          final result = await _authApi.requestOtp(
            phone: request.phone,
            name: request.name,
          );
          _requestCode(
            DemoSignInRequest(
              name: request.name,
              phone: result['phone'] as String,
            ),
          );
        } catch (error) {
          if (context.mounted)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$error')));
        }
      },
    );
  }
}

class DemoSignInRequest {
  const DemoSignInRequest({required this.name, required this.phone});

  final String name;
  final String phone;
}

class AccountInfo {
  const AccountInfo({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;
  final String phone;
}

class _LoginSplash extends StatefulWidget {
  const _LoginSplash({
    required this.onContinue,
    required this.onScanBackend,
    required this.onScanSignInQr,
  });

  final Future<void> Function(DemoSignInRequest) onContinue;
  final Future<void> Function() onScanBackend;
  final Future<void> Function() onScanSignInQr;

  @override
  State<_LoginSplash> createState() => _LoginSplashState();
}

class _LoginSplashState extends State<_LoginSplash> {
  final _phoneController = TextEditingController(text: '71234567');
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _phone => _phoneController.text;

  String _formatPhone(String digits) {
    if (digits.length <= 3) return digits;
    return '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
  }

  void _submit({String name = ''}) {
    if (_phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the 8-digit phone number linked to your demo profile.',
          ),
        ),
      );
      return;
    }
    widget.onContinue(
      DemoSignInRequest(name: name, phone: '+267 ${_formatPhone(_phone)}'),
    );
  }

  Future<void> _createAccount() async {
    _nameController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a demo profile'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
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
                Navigator.pop(dialogContext, _nameController.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted || name == null) return;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a name to continue with the demo profile.'),
        ),
      );
      return;
    }
    _submit(name: name);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAF8),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AuthBrandHeader(),
                const SizedBox(height: 38),
                const Icon(Icons.spa_outlined, size: 42, color: _forest),
                const SizedBox(height: 16),
                const Text(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Your harvest, your sensors.\nAll in one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF65776F),
                  ),
                ),
                const SizedBox(height: 26),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Log in to your account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 13),
                        const Text(
                          'Mobile number',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF465A50),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          decoration: InputDecoration(
                            prefixText: '+267  |  ',
                            hintText: '71 234 567',
                            filled: true,
                            fillColor: const Color(0xFFF8FAF8),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: const BorderSide(
                                color: Color(0xFFE6ECE7),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: const BorderSide(
                                color: Color(0xFFE6ECE7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Use the number linked to your farmer account.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF65776F),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => _submit(),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                          label: const Text('Continue with OTP'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _forest,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              await widget.onScanSignInQr();
                            } catch (error) {
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not sign in: $error'),
                                  ),
                                );
                            }
                          },
                          icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                          label: const Text('Scan sign-in QR'),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              await widget.onScanBackend();
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Backend connected. You can now request your sign-in PIN.',
                                    ),
                                  ),
                                );
                            } catch (error) {
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not connect: $error'),
                                  ),
                                );
                            }
                          },
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 17,
                          ),
                          label: const Text('Scan backend QR'),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sign in with a one-time PIN.\nNo password to remember.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.4,
                            color: Color(0xFF65776F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _createAccount,
                  child: const Text(
                    'New farmer? Create an account',
                    style: TextStyle(
                      color: _forest,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const _AuthDemoNotice(
                  text:
                      'Demo only. Authentication and SMS are not connected; no PIN will be sent.',
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Need help signing in? Get support',
                    style: TextStyle(color: _forest, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    required this.phone,
    required this.onBack,
    required this.onContinue,
    required this.onScanQr,
    super.key,
  });

  final String phone;
  final VoidCallback onBack;
  final Future<void> Function(String code) onContinue;
  final Future<void> Function() onScanQr;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _showDemoMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _verify() async {
    final code = _controllers.map((controller) => controller.text).join();
    try {
      await widget.onContinue(code);
    } catch (error) {
      _showDemoMessage('$error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAF8),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AuthBrandHeader(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.chevron_left, size: 17),
                    label: const Text('Back to login'),
                    style: TextButton.styleFrom(
                      foregroundColor: _forest,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Icon(
                  Icons.verified_user_outlined,
                  size: 38,
                  color: _forest,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Verify your number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Enter the 6-digit one-time PIN for',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF65776F)),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.phone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                TextButton(
                  onPressed: widget.onBack,
                  child: const Text(
                    'Change number',
                    style: TextStyle(color: _forest, fontSize: 11),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'One-time PIN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            6,
                            (index) => SizedBox(
                              width: 39,
                              height: 44,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1),
                                ],
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAF8),
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(9),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE6ECE7),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(9),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE6ECE7),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(9),
                                    borderSide: const BorderSide(
                                      color: _forest,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 5) {
                                    _focusNodes[index + 1].requestFocus();
                                  }
                                  if (value.isEmpty && index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              await widget.onScanQr();
                            } catch (error) {
                              _showDemoMessage('$error');
                            }
                          },
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Scan sign-in QR code'),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed:
                              _controllers.every(
                                (controller) => controller.text.length == 1,
                              )
                              ? _verify
                              : null,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                          label: const Text('Verify & continue'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _forest,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Didn’t receive a PIN?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFF65776F)),
                ),
                TextButton(
                  onPressed: () => _showDemoMessage(
                    'No PIN was sent. This is a local demo screen.',
                  ),
                  child: const Text(
                    'Resend PIN',
                    style: TextStyle(color: _forest, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 8),
                const _AuthDemoNotice(
                  text:
                      'Demo only. Use the sample PIN to illustrate this flow. No SMS is sent and no account is authenticated.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFE2F1E6),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.eco_rounded, size: 14, color: _forest),
      ),
      const SizedBox(width: 8),
      const Text(
        'Peo Yame',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: _forest,
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE2F1E6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Demo',
          style: TextStyle(fontSize: 10, color: _forest),
        ),
      ),
    ],
  );
}

class _AuthDemoNotice extends StatelessWidget {
  const _AuthDemoNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5DF),
      border: Border.all(color: const Color(0xFFF1DDA7)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: Color(0xFF765D24),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              height: 1.3,
              color: Color(0xFF765D24),
            ),
          ),
        ),
      ],
    ),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.account,
    required this.onLogout,
    required this.onEditName,
    required this.onLoadFarmerCrops,
    required this.onDeleteFarmerCrop,
    super.key,
  });

  final AccountInfo account;
  final VoidCallback onLogout;
  final Future<void> Function(String name) onEditName;
  final Future<List<Map<String, dynamic>>> Function() onLoadFarmerCrops;
  final Future<void> Function(int id) onDeleteFarmerCrop;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;
  String _baseUrl = defaultApiBaseUrl;
  int _selectedTab = 0;
  bool _showBackendAddress = false;
  DateTime _sensorStartedAt = DateTime.now();

  Future<void> _exportActionLog(BuildContext buttonContext) async {
    try {
      final sharePositionOrigin = _sharePositionOrigin(buttonContext);
      final markdown = await _controller.exportActionLog();
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(utf8.encode(markdown), mimeType: 'text/markdown'),
          ],
          fileNameOverrides: const ['peo-yame-actions.md'],
          title: 'Peo Yame activity log',
          sharePositionOrigin: sharePositionOrigin,
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
      final sharePositionOrigin = _sharePositionOrigin(buttonContext);
      final csv = await _controller.exportReadingsCsv();
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv')],
          fileNameOverrides: const ['peo-yame-readings.csv'],
          title: 'Peo Yame sensor data for Excel',
          sharePositionOrigin: sharePositionOrigin,
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
    _controller.loadCrops();
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
            TextButton.icon(
              onPressed: () async {
                final scanned = await Navigator.of(dialogContext).push<String>(
                  MaterialPageRoute<String>(
                    builder: (_) => const _BackendQrScannerPage(),
                  ),
                );
                if (scanned != null) {
                  textController.text = scanned;
                  setDialogState(() => validationMessage = '');
                }
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Scan QR code'),
            ),
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

  Future<void> _openAccounts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AccountsScreen(
          name: widget.account.name,
          phone: widget.account.phone,
          onEditName: widget.onEditName,
          onLoadFarmerCrops: widget.onLoadFarmerCrops,
          onDeleteFarmerCrop: widget.onDeleteFarmerCrop,
          onLogout: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            widget.onLogout();
          },
          onDestinationSelected: (index) {
            if (mounted) setState(() => _selectedTab = index);
          },
        ),
      ),
    );
  }

  Future<void> _refreshSensors() async {
    await _controller.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _controller.errorMessage == null
              ? 'Demo sensor readings refreshed.'
              : 'No readings yet. Check Wi-Fi and the monitor address.',
        ),
      ),
    );
  }

  Future<void> _restartSensors() async {
    setState(() => _sensorStartedAt = DateTime.now());
    _controller.recordAction('Restarted demo sensor session');
    await _controller.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Demo sensor session restarted. No physical sensor was restarted.',
        ),
      ),
    );
  }

  Future<void> _addCrop() async {
    final fields = List.generate(5, (_) => TextEditingController());
    final labels = [
      'Crop name',
      'Minimum temperature (°C)',
      'Maximum temperature (°C)',
      'Minimum humidity (%)',
      'Maximum humidity (%)',
    ];
    String? message;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add a crop'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < fields.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: fields[i],
                        keyboardType: i == 0
                            ? TextInputType.text
                            : const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                        decoration: InputDecoration(
                          labelText: labels[i],
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  if (message != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        message!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const Text(
                    'Use values that keep the crop safe during storage.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF65776F)),
                  ),
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
                final numbers = fields
                    .skip(1)
                    .map(
                      (controller) => double.tryParse(controller.text.trim()),
                    )
                    .toList();
                if (fields.first.text.trim().isEmpty ||
                    numbers.any((value) => value == null)) {
                  setDialogState(
                    () => message =
                        'Enter a crop name and all four number values.',
                  );
                  return;
                }
                if (numbers[0]! >= numbers[1]! ||
                    numbers[2]! < 0 ||
                    numbers[3]! > 100 ||
                    numbers[2]! >= numbers[3]!) {
                  setDialogState(
                    () => message =
                        'Check that each minimum is lower than its maximum. Humidity must be from 0 to 100%.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save crop'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      try {
        await _controller.addCrop(
          name: fields[0].text.trim(),
          minTemp: double.parse(fields[1].text),
          maxTemp: double.parse(fields[2].text),
          minHumidity: double.parse(fields[3].text),
          maxHumidity: double.parse(fields[4].text),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crop saved to the monitor database.'),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not save crop. Check the connection or use a different crop name.',
              ),
            ),
          );
        }
      }
    }
    for (final field in fields) {
      field.dispose();
    }
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
        final connected = _controller.isBackendConnected;
        final status = _controller.status;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: _header,
            foregroundColor: Colors.white,
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
                label: 'Overview',
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
    _FarmerGreeting(
      userName: widget.account.name,
      onAccountTap: _openAccounts,
      onLogout: widget.onLogout,
    ),
    const SizedBox(height: 16),
    if (status != null) ...[
      _StatusHero(status: status, offline: _controller.errorMessage != null),
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
        crops: _controller.crops,
        isChanging: _controller.isChangingHarvest,
        onChanged: _controller.setHarvest,
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _addCrop,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add crop'),
        ),
      ),
      const SizedBox(height: 18),
    ],
    _SectionTitle(
      title: 'Recent readings',
      trailing: Text(
        '${_controller.history.length}',
        style: const TextStyle(color: Color(0xFF65776F)),
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
      style: TextStyle(color: Color(0xFF65776F), fontSize: 13),
    ),
    const SizedBox(height: 16),
    _TrendAtAGlance(points: _controller.trends, range: _controller.trendRange),
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

  List<Widget> _alertsContent(StatusResponse? status) {
    Alert? attentionAlert;
    for (final alert in _controller.alerts) {
      if (!alert.acknowledged) {
        attentionAlert = alert;
        break;
      }
    }

    return [
      const _SectionTitle(title: 'Alerts'),
      const SizedBox(height: 4),
      const Text(
        'Storage alerts and notifications',
        style: TextStyle(color: Color(0xFF65776F), fontSize: 13),
      ),
      const SizedBox(height: 14),
      _CropQualityCard(status: status),
      const SizedBox(height: 16),
      if (attentionAlert != null) ...[
        const _SectionTitle(title: 'Needs attention'),
        const SizedBox(height: 8),
        _AlertBreakdownCard(
          alert: attentionAlert,
          fallbackReading: _readingForAlert(attentionAlert, status),
          fallbackThreshold: status?.threshold,
        ),
        const SizedBox(height: 16),
      ] else if (status?.breached ?? false) ...[
        const _SectionTitle(title: 'Needs attention'),
        const SizedBox(height: 8),
        _StatusHero(status: status!, offline: _controller.errorMessage != null),
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
      if (_controller.demoMode) ...[
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.notifications_active_outlined,
              color: _forest,
            ),
            title: const Text(
              'Trigger demo breach',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Cycle through crop quality impact levels',
              style: TextStyle(fontSize: 12),
            ),
            trailing: _controller.isTriggering
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _controller.isTriggering
                ? null
                : _controller.triggerDemoBreach,
          ),
        ),
      ],
    ];
  }

  Reading? _readingForAlert(Alert alert, StatusResponse? status) {
    for (final reading in _controller.history) {
      if (reading.id == alert.readingId) return reading;
    }
    final latest = status?.latest;
    return latest?.id == alert.readingId ? latest : null;
  }

  List<Widget> _settingsContent(StatusResponse? status) => [
    const _SectionTitle(title: 'Settings'),
    const SizedBox(height: 4),
    const Text(
      'Manage your storage monitor',
      style: TextStyle(color: Color(0xFF65776F), fontSize: 13),
    ),
    const SizedBox(height: 16),
    const _SectionTitle(title: 'Account information'),
    const SizedBox(height: 8),
    Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _AccountDetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Name',
              value: widget.account.name,
            ),
            const Divider(height: 1),
            _AccountDetailRow(
              icon: Icons.mail_outline_rounded,
              label: widget.account.email == 'Demo profile'
                  ? 'Profile'
                  : 'Email',
              value: widget.account.email,
            ),
            const Divider(height: 1),
            _AccountDetailRow(
              icon: Icons.phone_outlined,
              label: 'Number',
              value: widget.account.phone,
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 16),
    const _SectionTitle(title: 'Hardware package'),
    const SizedBox(height: 8),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors_rounded, color: _forest),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Demo sensor package',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        status != null && _controller.errorMessage == null
                            ? 'Demo readings are coming in'
                            : 'Waiting for the storage monitor',
                        style: const TextStyle(
                          color: Color(0xFF65776F),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.circle,
                  size: 9,
                  color: status != null && _controller.errorMessage == null
                      ? const Color(0xFF46A56A)
                      : const Color(0xFFD9A441),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Demo uptime  ${_formatUptime(DateTime.now().difference(_sensorStartedAt))}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'These are practice readings. No physical sensors are connected yet.',
              style: TextStyle(color: Color(0xFF65776F), fontSize: 12),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.router_outlined, color: _forest),
              title: const Text('Monitor connection address'),
              subtitle: Text(
                _showBackendAddress ? _baseUrl : 'Address hidden',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: _showBackendAddress ? 'Hide address' : 'Show address',
                onPressed: () =>
                    setState(() => _showBackendAddress = !_showBackendAddress),
                icon: Icon(
                  _showBackendAddress
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              onTap: _editServerAddress,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _refreshSensors,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh sensor'),
                ),
                OutlinedButton.icon(
                  onPressed: _restartSensors,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Restart sensors'),
                ),
              ],
            ),
          ],
        ),
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
    Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.science_outlined, color: _forest),
        title: const Text('Demo mode'),
        subtitle: Text(
          _controller.demoMode
              ? 'Demo alert controls are available on the Alerts screen.'
              : 'Enable the demo alert control for testing.',
        ),
        value: _controller.demoMode,
        onChanged: (enabled) => _controller.setDemoMode(enabled),
      ),
    ),
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

class _AccountDetailRow extends StatelessWidget {
  const _AccountDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

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
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF65776F), fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _CropQualityCard extends StatelessWidget {
  const _CropQualityCard({required this.status});

  final StatusResponse? status;

  @override
  Widget build(BuildContext context) {
    final estimate = _estimateCropQuality(status);
    final color = estimate == null
        ? const Color(0xFF65776F)
        : estimate >= 80
        ? _forest
        : estimate >= 55
        ? const Color(0xFF8A6C27)
        : const Color(0xFF9E332B);
    final label = estimate == null
        ? 'Waiting for readings'
        : estimate >= 80
        ? 'Good storage conditions'
        : estimate >= 55
        ? 'Conditions need watching'
        : 'Conditions may harm the crop';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.spa_outlined, color: _forest),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Estimated crop quality',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  estimate == null ? '—' : '$estimate%',
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: estimate == null ? null : estimate / 100,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              color: color,
              backgroundColor: const Color(0xFFE8EEE8),
            ),
            const SizedBox(height: 10),
            const Text(
              'A rough estimate from temperature and humidity only. It does not inspect the crop.',
              style: TextStyle(color: Color(0xFF65776F), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertBreakdownCard extends StatelessWidget {
  const _AlertBreakdownCard({
    required this.alert,
    required this.fallbackReading,
    required this.fallbackThreshold,
  });

  final Alert alert;
  final Reading? fallbackReading;
  final Threshold? fallbackThreshold;

  @override
  Widget build(BuildContext context) {
    final reading = alert.reading ?? fallbackReading;
    final threshold = alert.threshold ?? fallbackThreshold;
    final commodity = alert.commodity ?? threshold?.commodity ?? 'crop';
    final sentAt = DateTime.tryParse(alert.sentAt);
    final age = sentAt == null ? null : DateTime.now().difference(sentAt);
    final risk = _estimateDegradationRisk(reading, threshold, age);
    final riskColor = risk == 'High'
        ? const Color(0xFF9E332B)
        : risk == 'Moderate'
        ? const Color(0xFF8A6C27)
        : _forest;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFF9E332B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$commodity storage alert',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Raised ${_formatDate(alert.sentAt)}${age == null ? '' : ' · ${_elapsedLabel(age)} ago'}',
              style: const TextStyle(color: Color(0xFF65776F), fontSize: 11),
            ),
            const SizedBox(height: 14),
            if (reading != null && threshold != null) ...[
              _AlertReadingRow(
                label: 'Temperature',
                value: '${_fmt(reading.temperature)}°C',
                safeRange:
                    '${_fmt(threshold.minTemp)}–${_fmt(threshold.maxTemp)}°C',
                outside:
                    reading.temperature < threshold.minTemp ||
                    reading.temperature > threshold.maxTemp,
              ),
              const SizedBox(height: 8),
              _AlertReadingRow(
                label: 'Humidity',
                value: '${_fmt(reading.humidity)}%',
                safeRange:
                    '${_fmt(threshold.minHumidity)}–${_fmt(threshold.maxHumidity)}%',
                outside:
                    reading.humidity < threshold.minHumidity ||
                    reading.humidity > threshold.maxHumidity,
              ),
              const SizedBox(height: 14),
              const Text(
                'Why this matters',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 5),
              Text(
                _alertReason(commodity, reading, threshold),
                style: const TextStyle(
                  color: Color(0xFF53645B),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ] else ...[
              const Text(
                'This alert has no saved sensor reading. Reconnect the monitor to get more details.',
                style: TextStyle(color: Color(0xFF53645B), fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated degradation risk: $risk',
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rough warning from the alert time and how far readings passed the safe range. Assumes moderately clean produce and that conditions continued. It is not a measured percentage of crop damage.',
                    style: TextStyle(
                      color: Color(0xFF53645B),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertReadingRow extends StatelessWidget {
  const _AlertReadingRow({
    required this.label,
    required this.value,
    required this.safeRange,
    required this.outside,
  });

  final String label;
  final String value;
  final String safeRange;
  final bool outside;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        outside ? Icons.error_outline_rounded : Icons.check_circle_outline,
        size: 18,
        color: outside ? const Color(0xFF9E332B) : _forest,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          '$label: $value',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      Text(
        'Safe: $safeRange',
        style: const TextStyle(color: Color(0xFF65776F), fontSize: 10),
      ),
    ],
  );
}

String _estimateDegradationRisk(
  Reading? reading,
  Threshold? threshold,
  Duration? timeSinceAlert,
) {
  if (reading == null || threshold == null) return 'Unknown';

  double relativeExcursion(double value, double minimum, double maximum) {
    final difference = value < minimum
        ? minimum - value
        : value > maximum
        ? value - maximum
        : 0.0;
    final width = (maximum - minimum).abs();
    return width == 0 ? (difference == 0 ? 0 : 1) : difference / width;
  }

  final temperatureExcursion = relativeExcursion(
    reading.temperature,
    threshold.minTemp,
    threshold.maxTemp,
  );
  final humidityExcursion = relativeExcursion(
    reading.humidity,
    threshold.minHumidity,
    threshold.maxHumidity,
  );
  final largestExcursion = temperatureExcursion > humidityExcursion
      ? temperatureExcursion
      : humidityExcursion;
  final duration = timeSinceAlert ?? Duration.zero;
  if (duration >= const Duration(hours: 6) || largestExcursion >= .5) {
    return 'High';
  }
  if (duration >= const Duration(hours: 1) || largestExcursion >= .15) {
    return 'Moderate';
  }
  return 'Low';
}

String _alertReason(String commodity, Reading reading, Threshold threshold) {
  final isMaize = commodity.toLowerCase() == 'maize';
  final reasons = <String>[];
  if (reading.temperature > threshold.maxTemp) {
    reasons.add(
      isMaize
          ? 'Warm grain can spoil faster, especially when the grain is damp.'
          : 'Warm storage can speed ripening and softening.',
    );
  } else if (reading.temperature < threshold.minTemp) {
    reasons.add('This temperature is outside the crop’s recommended range.');
  }
  if (reading.humidity > threshold.maxHumidity) {
    reasons.add(
      'High air moisture can encourage mold when produce is damp. Air humidity does not tell us the crop’s own moisture.',
    );
  } else if (reading.humidity < threshold.minHumidity) {
    reasons.add('Very dry air can make fresh produce lose water and weight.');
  }
  return reasons.isEmpty
      ? 'The reading has returned to range. Check the crop and watch the next readings.'
      : reasons.join(' ');
}

String _elapsedLabel(Duration duration) {
  if (duration.isNegative) return 'just now';
  if (duration.inDays > 0) return '${duration.inDays} days';
  if (duration.inHours > 0) return '${duration.inHours} hours';
  if (duration.inMinutes > 0) return '${duration.inMinutes} minutes';
  return 'less than a minute';
}

int? _estimateCropQuality(StatusResponse? status) {
  final reading = status?.latest;
  final threshold = status?.threshold;
  if (reading == null || threshold == null) return null;

  double score(double value, double minimum, double maximum) {
    final distance = value < minimum
        ? minimum - value
        : value > maximum
        ? value - maximum
        : 0.0;
    final range = (maximum - minimum).abs();
    if (range == 0) return distance == 0 ? 100 : 0;
    return (100 - (distance / range * 100)).clamp(0, 100).toDouble();
  }

  final temperatureScore = score(
    reading.temperature,
    threshold.minTemp,
    threshold.maxTemp,
  );
  final humidityScore = score(
    reading.humidity,
    threshold.minHumidity,
    threshold.maxHumidity,
  );
  return ((temperatureScore + humidityScore) / 2).round().clamp(0, 100).toInt();
}

String _formatUptime(Duration duration) {
  final hours = duration.inHours;
  final days = hours ~/ 24;
  final remainingHours = hours % 24;
  final minutes = duration.inMinutes % 60;
  if (days > 0) return '${days}d ${remainingHours}h ${minutes}m';
  return '${remainingHours}h ${minutes}m';
}

Rect? _sharePositionOrigin(BuildContext context) {
  final renderBox = context.findRenderObject() as RenderBox?;
  if (renderBox == null) return null;
  return renderBox.localToGlobal(Offset.zero) & renderBox.size;
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
  const _FarmerGreeting({
    required this.userName,
    required this.onAccountTap,
    required this.onLogout,
  });

  final String userName;
  final VoidCallback onAccountTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PopupMenuButton<String>(
          tooltip: 'User menu',
          onSelected: (value) {
            if (value == 'accounts') onAccountTap();
            if (value == 'logout') onLogout();
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text(userName, style: const TextStyle(color: _forest)),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'accounts',
              child: Row(
                children: [
                  Icon(Icons.manage_accounts_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Accounts & crops'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Log out'),
                ],
              ),
            ),
          ],
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F2E9),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.person_outline_rounded, color: _forest),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'Your harvest at a glance',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF65776F)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.status, this.offline = false});

  final StatusResponse status;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final breached = status.breached;
    final latest = status.latest;
    final background = offline
        ? const Color(0xFF65552F)
        : breached
        ? const Color(0xFF8E342E)
        : _forest;
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [background, Color.lerp(background, Colors.black, .16)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
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
                offline
                    ? Icons.cloud_off_rounded
                    : breached
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offline
                      ? breached
                            ? 'Offline · last known alert'
                            : 'Connection lost · last known'
                      : breached
                      ? 'Attention needed'
                      : 'Conditions are safe',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            latest == null
                ? 'Waiting for the first reading'
                : offline
                ? 'Last reading ${_relativeTime(latest.recordedAt)} · reconnecting'
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
              style: const TextStyle(fontSize: 10, color: Color(0xFF65776F)),
            ),
            const SizedBox(height: 13),
            _RiskGauge(value: current, min: min, max: max),
            const SizedBox(height: 6),
            Text(
              'Safe ${_fmt(min)}–${_fmt(max)}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF65776F)),
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
              style: TextStyle(fontSize: 9, color: Color(0xFF65776F)),
            ),
            Text(
              'Low',
              style: TextStyle(fontSize: 9, color: Color(0xFF65776F)),
            ),
            Text(
              'High',
              style: TextStyle(fontSize: 9, color: Color(0xFF65776F)),
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
    required this.crops,
    required this.isChanging,
    required this.onChanged,
  });

  final StatusResponse status;
  final List<Threshold> crops;
  final bool isChanging;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final latest = status.latest;
    final days = latest == null ? null : _estimateDays(status);
    final cropOptions = <String>{
      status.threshold.commodity,
      ...crops.map((crop) => crop.commodity),
    };
    if (cropOptions.length == 1) {
      cropOptions.addAll(['Maize', 'Tomato']);
    }
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
                    style: TextStyle(fontSize: 11, color: Color(0xFF65776F)),
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
                    items: cropOptions
                        .map(
                          (crop) =>
                              DropdownMenuItem(value: crop, child: Text(crop)),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Storage estimate',
                  style: TextStyle(fontSize: 11, color: Color(0xFF65776F)),
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
                  color: active ? _forest : const Color(0xFF65776F),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TrendAtAGlance extends StatelessWidget {
  const _TrendAtAGlance({required this.points, required this.range});

  final List<TrendPoint> points;
  final String range;

  @override
  Widget build(BuildContext context) {
    final temperatures = points.map((point) => point.temperature).toList();
    final humidities = points.map((point) => point.humidity).toList();
    if (points.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'At a glance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Low and high readings will appear when data is available.',
                style: const TextStyle(color: Color(0xFF65776F), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final temperatureLow = temperatures.reduce((a, b) => a < b ? a : b);
    final temperatureHigh = temperatures.reduce((a, b) => a > b ? a : b);
    final humidityLow = humidities.reduce((a, b) => a < b ? a : b);
    final humidityHigh = humidities.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'At a glance · ${_rangeLabel(range)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _TrendStat(
                    icon: Icons.thermostat_rounded,
                    title: 'Temperature',
                    low: '${_fmt(temperatureLow)}°C',
                    high: '${_fmt(temperatureHigh)}°C',
                    color: const Color(0xFF25865C),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _TrendStat(
                    icon: Icons.water_drop_outlined,
                    title: 'Humidity',
                    low: '${_fmt(humidityLow)}%',
                    high: '${_fmt(humidityHigh)}%',
                    color: const Color(0xFF4E81CE),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendStat extends StatelessWidget {
  const _TrendStat({
    required this.icon,
    required this.title,
    required this.low,
    required this.high,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String low;
  final String high;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text('Low  $low', style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 3),
      Text('High  $high', style: const TextStyle(fontSize: 12)),
    ],
  );
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
    final sampled = _samplePoints(points, 36);
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
                _Legend(color: Color(0xFF25865C), text: 'Temperature °C'),
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
                          color: Color(0xFF65776F),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : CustomPaint(painter: _TrendPainter(points: sampled)),
            ),
            const SizedBox(height: 4),
            Text(
              points.any((point) => point.synthetic)
                  ? '${_rangeLabel(range)} · includes stored simulated hourly history; recent points update live from the backend.'
                  : '${_rangeLabel(range)} · readings update live from the backend.',
              style: const TextStyle(fontSize: 10, color: Color(0xFF65776F)),
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
    _drawBars(
      canvas,
      chart,
      points.map((p) => p.temperature).toList(),
      const Color(0xFF25865C),
      seriesIndex: 0,
    );
    _drawBars(
      canvas,
      chart,
      points.map((p) => p.humidity).toList(),
      const Color(0xFF4E81CE),
      seriesIndex: 1,
    );
  }

  void _drawBars(
    Canvas canvas,
    Rect rect,
    List<double> values,
    Color color, {
    required int seriesIndex,
  }) {
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final spread = maximum - minimum;
    final slotWidth = rect.width / values.length;
    final barWidth = (slotWidth * .32).clamp(2.0, 7.0).toDouble();
    final gap = slotWidth * .08;
    final groupWidth = barWidth * 2 + gap;
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final normalized = spread == 0 ? .55 : (values[i] - minimum) / spread;
      final height = rect.height * (.16 + normalized * .78);
      final x =
          rect.left +
          i * slotWidth +
          (slotWidth - groupWidth) / 2 +
          seriesIndex * (barWidth + gap);
      final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, rect.bottom - height, barWidth, height),
        const Radius.circular(3),
      );
      canvas.drawRRect(bar, paint);
    }
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
          Icon(icon, color: const Color(0xFF65776F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF65776F)),
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
      color: const Color(0xFFFFF5DB),
      border: Border.all(color: const Color(0xFFF0DBA6)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.wifi_off_rounded, color: Color(0xFF8A6C27), size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(color: Color(0xFF624D1C), fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Open Settings to check the backend address.',
                style: TextStyle(
                  color: Color(0xFF624D1C),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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

class _AuthQrScannerPage extends StatefulWidget {
  const _AuthQrScannerPage();
  @override
  State<_AuthQrScannerPage> createState() => _AuthQrScannerPageState();
}

class _AuthQrScannerPageState extends State<_AuthQrScannerPage> {
  bool _finished = false;
  late final MobileScannerController _scannerController =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  void _handleDetection(BarcodeCapture capture) {
    if (_finished) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final uri = Uri.parse(data['backend'] as String);
        final parts = uri.host.split('.').map(int.tryParse).toList();
        final local =
            parts.length == 4 &&
            parts.every((part) => part != null) &&
            (parts[0] == 10 ||
                (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31) ||
                (parts[0] == 192 && parts[1] == 168));
        if (data['type'] == 'peo-yame-auth' &&
            uri.hasAuthority &&
            local &&
            RegExp(r'^\d{6}$').hasMatch('${data['code']}')) {
          _finished = true;
          Navigator.of(context).pop(raw);
          return;
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is not a valid Peo Yame sign-in QR code.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan sign-in QR code')),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleDetection,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Allow camera access to scan the sign-in code. ${error.errorCode.message}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Scan the temporary QR code shown on the backend sign-in page.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BackendQrScannerPage extends StatefulWidget {
  const _BackendQrScannerPage();

  @override
  State<_BackendQrScannerPage> createState() => _BackendQrScannerPageState();
}

class _BackendQrScannerPageState extends State<_BackendQrScannerPage> {
  bool _finished = false;
  bool _showedInvalidCode = false;
  late final MobileScannerController _scannerController =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  void _handleDetection(BarcodeCapture capture) {
    if (_finished) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final uri = Uri.tryParse(raw.trim());
      if (uri == null) continue;
      final valid =
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty &&
          _isPrivateIpv4(uri.host) &&
          uri.userInfo.isEmpty &&
          (uri.path.isEmpty || uri.path == '/') &&
          !uri.hasQuery &&
          !uri.hasFragment;
      if (valid) {
        _finished = true;
        final baseUrl = uri
            .replace(path: '', query: '', fragment: '')
            .toString();
        Navigator.of(context).pop(
          baseUrl.endsWith('/')
              ? baseUrl.substring(0, baseUrl.length - 1)
              : baseUrl,
        );
        return;
      }
      if (!_showedInvalidCode) {
        _showedInvalidCode = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This QR code is not a Peo Yame backend address.'),
          ),
        );
      }
    }
  }

  bool _isPrivateIpv4(String host) {
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 ||
        parts.any((part) => part == null || part < 0 || part > 255)) {
      return false;
    }
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 169 && b == 254) ||
        (a == 100 && b >= 64 && b <= 127);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan backend QR code'),
      backgroundColor: _header,
      foregroundColor: Colors.white,
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleDetection,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Camera access is needed to scan the QR code. Allow camera access, or close this screen and enter the address manually. (${error.errorCode.message})',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Point your camera at the QR code on the computer dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ],
    ),
  );
}
