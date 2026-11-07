import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Threshold;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'account_screens.dart';
import 'api_service.dart';
import 'config.dart';
import 'dashboard_controller.dart';
import 'models.dart';

const _forest = Color(0xFF176B4A);
const _header = Color(0xFF10251F);
const _canvas = Color(0xFFF3F7F3);
const _ink = Color(0xFF172923);
const _red = Color(0xFFB84036);

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
  static const _demoAccount = AccountInfo(
    name: 'Mr Lesego Lefoko',
    email: 'LLefoko@email.co.bw',
    phone: '',
  );
  final ApiService _authApi = ApiService();
  AccountInfo? _account;
  String? _authToken;
  bool _authEnabled = false;
  bool _checkingBackend = true;
  bool _demoSelected = false;

  @override
  void initState() {
    super.initState();
    _restoreSavedSession();
  }

  Future<void> _restoreSavedSession() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _authApi.baseUrl = normalizeApiBaseUrl(
        preferences.getString(apiBaseUrlPreferenceKey) ?? defaultApiBaseUrl,
      );
      final token = preferences.getString('farmer_session_token');
      final health = await _authApi.checkConnection();
      if (_demoSelected) return;
      _authEnabled = health['authEnabled'] == true;
      if (token != null && _authEnabled) {
        try {
          final session = await _authApi.restoreSession(token);
          if (_demoSelected) return;
          _setAccount(session['farmer'] as Map<String, dynamic>, token);
        } catch (_) {
          await preferences.remove('farmer_session_token');
        }
      }
    } catch (_) {
      // Demo entry remains available when the backend cannot be reached.
    } finally {
      if (mounted) setState(() => _checkingBackend = false);
    }
  }

  void _setAccount(Map<String, dynamic> farmer, String token) {
    _authToken = token;
    _authApi.authToken = token;
    _account = AccountInfo(
      name: farmer['name'] as String? ?? 'Farmer',
      email: farmer['email'] as String? ?? '',
      phone: farmer['phone'] as String? ?? '',
    );
  }

  void _enterDemo() {
    _demoSelected = true;
    final previousToken = _authApi.authToken;
    _authApi.authToken = null;
    setState(() {
      _authToken = null;
      _account = _demoAccount;
    });
    unawaited(() async {
      try {
        await (await SharedPreferences.getInstance()).remove('farmer_session_token');
      } catch (_) {}
      if (previousToken != null) {
        final api = ApiService(baseUrl: _authApi.baseUrl, authToken: previousToken);
        try { await api.signOut(); } catch (_) {} finally { api.dispose(); }
      }
    }());
  }

  Future<void> _openAuth({required bool register}) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _FarmerAccessPage(
          baseUrl: _authApi.baseUrl,
          createAccountFirst: register,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _authApi.baseUrl = normalizeApiBaseUrl(result['baseUrl'] as String? ?? _authApi.baseUrl);
    final farmer = result['farmer'] as Map<String, dynamic>;
    final token = result['token'] as String;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(apiBaseUrlPreferenceKey, _authApi.baseUrl);
    await preferences.setString('farmer_session_token', token);
    _demoSelected = false;
    setState(() => _setAccount(farmer, token));
  }

  Future<void> _logout() async {
    final token = _authToken;
    if (token != null) {
      try {
        await ApiService(baseUrl: _authApi.baseUrl, authToken: token).signOut();
      } catch (_) {}
      try {
        await (await SharedPreferences.getInstance()).remove('farmer_session_token');
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _authToken = null;
      _authApi.authToken = null;
      _account = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    return account == null
        ? _DemoSplash(
            onEnterDemo: _enterDemo,
            onSignIn: () => _openAuth(register: false),
            onCreateAccount: () => _openAuth(register: true),
            authEnabled: _authEnabled,
            checkingBackend: _checkingBackend,
          )
        : DashboardPage(
            account: account,
            token: _authToken,
            baseUrl: _authApi.baseUrl,
            onLogout: _logout,
          );
  }
}

class AccountInfo {
  const AccountInfo({required this.name, required this.email, required this.phone});

  final String name;
  final String email;
  final String phone;
}

class _DemoSplash extends StatelessWidget {
  const _DemoSplash({
    required this.onEnterDemo,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.authEnabled,
    required this.checkingBackend,
  });

  final VoidCallback onEnterDemo;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final bool authEnabled;
  final bool checkingBackend;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAF8),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/branding/peo-yame-128.png', width: 88, height: 88),
                const SizedBox(height: 16),
                const Text('Peo Yame', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 8),
                const Text('Storage monitoring for your harvest', textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF65776F))),
                const SizedBox(height: 26),
                Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Shared demo profile', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('Mr Lesego Lefoko'),
                    const Text('LLefoko@email.co.bw', style: TextStyle(color: Color(0xFF65776F))),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onEnterDemo,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Demo mode'),
                      style: FilledButton.styleFrom(backgroundColor: _forest,
                        foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onSignIn,
                      icon: const Icon(Icons.phone_android_rounded),
                      label: const Text('Sign in with phone number'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                    TextButton(
                      onPressed: onCreateAccount,
                      child: const Text('Create farmer account'),
                    ),
                    if (!authEnabled && !checkingBackend)
                      const Text(
                        'Phone sign-in is unavailable on this demo backend. You can still open Demo mode.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Color(0xFF65776F)),
                      ),
                  ],
                ))),
                const SizedBox(height: 12),
                const Text('Demo access opens the dashboard directly. It does not verify a phone number or create an authenticated account.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF65776F))),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FarmerAccessPage extends StatefulWidget {
  const _FarmerAccessPage({required this.baseUrl, required this.createAccountFirst});

  final String baseUrl;
  final bool createAccountFirst;

  @override
  State<_FarmerAccessPage> createState() => _FarmerAccessPageState();
}

class _FarmerAccessPageState extends State<_FarmerAccessPage> {
  final _formKey = GlobalKey<FormState>();
  late final ApiService _api;
  late final TextEditingController _baseUrl;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _authenticatorCode = TextEditingController();
  late bool _createAccount;
  bool _authEnabled = false;
  bool _checking = true;
  bool _submitting = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createAccount = widget.createAccountFirst;
    _baseUrl = TextEditingController(text: widget.baseUrl);
    _api = ApiService(baseUrl: widget.baseUrl);
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    try {
      _api.baseUrl = normalizeApiBaseUrl(_baseUrl.text);
      final health = await _api.checkConnection();
      if (!mounted) return;
      setState(() => _authEnabled = health['authEnabled'] == true);
    } catch (error) {
      if (mounted) setState(() => _error = 'Enter the PC backend address and check that it is running.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      _api.baseUrl = normalizeApiBaseUrl(_baseUrl.text);
      final health = await _api.checkConnection();
      if (health['authEnabled'] != true) {
        throw Exception('Sign-in is disabled on this backend. Demo mode is still available.');
      }
      final result = _createAccount
          ? await _api.registerFarmer(name: _name.text.trim(), phone: _phone.text.trim(), password: _password.text)
          : await _api.signIn(phone: _phone.text.trim(), password: _password.text, authenticatorCode: _authenticatorCode.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop({...result, 'baseUrl': _api.baseUrl});
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _scanSignInQr() async {
    _api.baseUrl = normalizeApiBaseUrl(_baseUrl.text);
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => _QrScannerPage(api: _api)),
    );
    if (result == null || !mounted) return;
    Navigator.of(context).pop({...result, 'baseUrl': _api.baseUrl});
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _authenticatorCode.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_createAccount ? 'Create farmer account' : 'Farmer sign in')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Use your phone number and password.', style: TextStyle(color: Color(0xFF65776F))),
      const SizedBox(height: 16),
      TextField(
        controller: _baseUrl,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(labelText: 'Backend address', hintText: '192.168.1.42:3000', helperText: 'Enter the address shown on the PC running Peo Yame.'),
        onEditingComplete: _checkBackend,
      ),
      const SizedBox(height: 12),
      if (_checking) const LinearProgressIndicator(),
      if (!_authEnabled && !_checking)
        const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Account sign-in is not enabled on this backend. Demo mode remains available without verification.', style: TextStyle(color: Color(0xFF765D24)))),
      Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_createAccount) ...[
          TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Your name'), validator: (value) => (value ?? '').trim().length < 2 ? 'Enter your name.' : null),
          const SizedBox(height: 12),
        ],
        TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Botswana phone number', hintText: '+267 71 234 567', prefixIcon: Icon(Icons.phone_android_rounded)), validator: (value) => (value ?? '').replaceAll(RegExp(r'\D'), '').length < 8 ? 'Enter your 8-digit phone number.' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _password, obscureText: !_showPassword, decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility))), validator: (value) => (value ?? '').length < (_createAccount ? 10 : 1) ? (_createAccount ? 'Use at least 10 characters.' : 'Enter your password.') : null),
        if (!_createAccount) ...[
          const SizedBox(height: 12),
          TextField(controller: _authenticatorCode, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Authenticator code (if enabled)', counterText: ''),),
        ],
      ])),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: _red))),
      const SizedBox(height: 16),
      FilledButton(onPressed: _submitting ? null : _submit, style: FilledButton.styleFrom(backgroundColor: _forest, minimumSize: const Size.fromHeight(50)), child: _submitting ? const CircularProgressIndicator() : Text(_createAccount ? 'Create account' : 'Sign in')),
      if (!_createAccount) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _submitting ? null : _scanSignInQr, icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Scan sign-in QR code'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48))),
      ],
      TextButton(onPressed: () => setState(() { _createAccount = !_createAccount; _error = null; }), child: Text(_createAccount ? 'Already have an account? Sign in' : 'New farmer? Create an account')),
    ])),
  );
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage({required this.api});
  final ApiService api;

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  bool _busy = false;
  String? _error;

  Uri? _qrServerUri(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('This sign-in code has an invalid backend address.');
    }
    return uri.replace(path: '', query: null, fragment: null);
  }

  bool _isLoopback(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '::1';

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_busy || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || uri.scheme != 'peoyame' || uri.pathSegments.isEmpty) {
      setState(() => _error = 'This QR code is not a Peo Yame sign-in code.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final challenge = uri.pathSegments.last;
      if (uri.host == 'mobile-login') {
        final qrServer = _qrServerUri(uri.queryParameters['server']);
        if (qrServer != null &&
            !_isLoopback(qrServer.host) &&
            qrServer.toString() != widget.api.baseUrl) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Use the same Peo Yame backend?'),
              content: Text('This sign-in code connects to ${qrServer.host}. Continue to use that backend on this phone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Continue')),
              ],
            ),
          );
          if (confirmed != true) {
            if (mounted) setState(() => _busy = false);
            return;
          }
          widget.api.baseUrl = qrServer.toString();
        }
        final result = await widget.api.exchangeMobileLoginQr(challenge);
        result['baseUrl'] = widget.api.baseUrl;
        if (mounted) Navigator.of(context).pop(result);
      } else if (uri.host == 'web-login') {
        if (widget.api.authToken == null) throw Exception('Sign in on this phone first, then scan the browser code.');
        final qrServer = _qrServerUri(uri.queryParameters['server']);
        if (qrServer != null &&
            !_isLoopback(qrServer.host) &&
            qrServer.toString() != widget.api.baseUrl) {
          throw Exception('This browser QR belongs to a different backend. Connect this phone to ${qrServer.host} first.');
        }
        await widget.api.approveWebLoginQr(challenge);
        if (mounted) Navigator.of(context).pop({'approved': true});
      } else {
        throw Exception('This QR code is not a Peo Yame sign-in code.');
      }
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = error.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan sign-in QR code')),
    body: Stack(children: [
      MobileScanner(onDetect: _handleCapture),
      Align(alignment: Alignment.bottomCenter, child: Container(width: double.infinity, padding: const EdgeInsets.all(18), color: Colors.black.withValues(alpha: .72), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Hold the QR code inside the frame', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        if (_busy) const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.white))),
      ]))),
    ]),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.account,
    required this.token,
    required this.baseUrl,
    required this.onLogout,
    super.key,
  });

  final AccountInfo account;
  final String? token;
  final String baseUrl;
  final VoidCallback onLogout;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;
  late String _accountName;
  late String _accountEmail;
  late String _accountPhone;
  String _baseUrl = defaultApiBaseUrl;
  int _selectedTab = 0;
  bool _showBackendAddress = false;
  bool _authenticatorEnabled = false;
  bool _loadingAuthenticator = false;
  int _observedAccountRevision = 0;
  String _cropGuideSearch = '';
  DateTime _sensorStartedAt = DateTime.now();

  List<Threshold> get _visibleCropGuides {
    final query = _cropGuideSearch.trim().toLowerCase();
    if (query.isEmpty) return _controller.crops;
    return _controller.crops.where((crop) =>
      '${crop.commodity} ${crop.cropGroup} ${crop.storageNote}'
          .toLowerCase().contains(query)).toList();
  }

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
    _accountName = widget.account.name;
    _accountEmail = widget.account.email;
    _accountPhone = widget.account.phone;
    _baseUrl = widget.baseUrl;
    _controller = DashboardController(
      api: ApiService(baseUrl: widget.baseUrl, authToken: widget.token),
    );
    _controller.addListener(_handleDashboardUpdate);
    _controller.demoMode = widget.token == null;
    _controller.loadCrops();
    _loadSavedAddress();
    if (widget.token != null) _refreshAuthenticatorStatus();
  }

  void _handleDashboardUpdate() {
    if (widget.token == null ||
        _observedAccountRevision == _controller.farmerAccountRevision) return;
    _observedAccountRevision = _controller.farmerAccountRevision;
    unawaited(_refreshFarmerProfile());
    unawaited(_refreshAuthenticatorStatus());
  }

  Future<void> _refreshFarmerProfile() async {
    final api = ApiService(baseUrl: _controller.baseUrl, authToken: widget.token);
    try {
      final account = await api.getFarmerAccount();
      if (!mounted) return;
      setState(() {
        _accountName = account['name'] as String? ?? _accountName;
        _accountEmail = account['email'] as String? ?? '';
        _accountPhone = account['phone'] as String? ?? _accountPhone;
      });
    } catch (_) {
      // Keep the last server-confirmed profile visible while reconnecting.
    } finally {
      api.dispose();
    }
  }

  Future<void> _refreshAuthenticatorStatus() async {
    if (widget.token == null) return;
    setState(() => _loadingAuthenticator = true);
    final api = ApiService(baseUrl: _controller.baseUrl, authToken: widget.token);
    try {
      final enabled = await api.getAuthenticatorEnabled();
      if (mounted) setState(() => _authenticatorEnabled = enabled);
    } catch (_) {
      // Keep the security controls usable if status lookup is temporarily unavailable.
    } finally {
      api.dispose();
      if (mounted) setState(() => _loadingAuthenticator = false);
    }
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
    _controller.startPolling(demoModeOverride: widget.token == null);
  }

  Future<void> _scanBrowserLoginQr() async {
    final api = ApiService(baseUrl: _controller.baseUrl, authToken: widget.token);
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => _QrScannerPage(api: api)),
    );
    api.dispose();
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web sign-in approved. Return to the browser.')),
      );
    }
  }

  Future<void> _editProfile() async {
    if (widget.token == null) return;
    final nameController = TextEditingController(text: _accountName);
    final emailController = TextEditingController(text: _accountEmail);
    String? validationError;
    final profile = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameController,
              autofocus: true,
              maxLength: 80,
              decoration: InputDecoration(labelText: 'Name', errorText: validationError),
            ),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              maxLength: 254,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final value = nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
                if (value.length < 2 || value.length > 80) {
                  setDialogState(() => validationError = 'Enter a name between 2 and 80 characters.');
                  return;
                }
                final email = emailController.text.trim();
                if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  setDialogState(() => validationError = 'Enter a valid email address or leave it blank.');
                  return;
                }
                Navigator.pop(dialogContext, {'name': value, 'email': email});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    emailController.dispose();
    if (profile == null || !mounted || (profile['name'] == _accountName && profile['email'] == _accountEmail)) return;
    final api = ApiService(baseUrl: _controller.baseUrl, authToken: widget.token);
    try {
      final account = await api.updateFarmerProfile(name: profile['name']!, email: profile['email']!);
      if (!mounted) return;
      setState(() {
        _accountName = account['name'] as String? ?? profile['name']!;
        _accountEmail = account['email'] as String? ?? _accountEmail;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update profile: ${error.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      api.dispose();
    }
  }

  Future<void> _setupAuthenticator() async {
    final api = ApiService(baseUrl: _controller.baseUrl, authToken: widget.token);
    try {
      String? code;
      if (_authenticatorEnabled) {
        code = await showDialog<String>(
          context: context,
          builder: (dialogContext) {
            final codeController = TextEditingController();
            return AlertDialog(
              title: const Text('Turn off authenticator sign-in?'),
              content: TextField(controller: codeController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Current 6-digit code', counterText: '')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, codeController.text.trim()), child: const Text('Turn off')),
              ],
            );
          },
        );
        if (code == null || code.isEmpty) return;
        await api.disableAuthenticator(code);
        if (mounted) {
          setState(() => _authenticatorEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authenticator sign-in is disabled.')));
        }
        return;
      }
      final setup = await api.setupAuthenticator();
      if (!mounted) return;
      code = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final codeController = TextEditingController();
          return AlertDialog(
            title: const Text('Set up authenticator'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add this key in Google Authenticator or another TOTP app, then enter its current six-digit code.'),
              const SizedBox(height: 12),
              SelectableText(setup['secret'] as String, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              TextField(controller: codeController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit code', counterText: '')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, codeController.text.trim()), child: const Text('Enable')),
            ],
          );
        },
      );
      if (code == null || code.isEmpty) return;
      await api.enableAuthenticator(code);
      if (mounted) {
        setState(() => _authenticatorEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authenticator sign-in is enabled.')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      api.dispose();
    }
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

  void _openSettings() {
    if (mounted) setState(() => _selectedTab = 4);
  }

  Future<void> _showSignInQr() async {
    final api = ApiService(baseUrl: _controller.baseUrl, authToken: widget.token);
    try {
      final challenge = await api.createMobileLoginQr(serverBaseUrl: _controller.baseUrl);
      if (!mounted) return;
      final qrData = challenge['qrCode'] as String;
      final comma = qrData.indexOf(',');
      if (!qrData.startsWith('data:image/') || comma < 0) {
        throw const FormatException('The server returned an invalid sign-in QR code.');
      }
      final expiresAt = DateTime.parse(challenge['expiresAt'] as String).toLocal();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sign in another phone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.memory(base64Decode(qrData.substring(comma + 1)), width: 240, height: 240),
              const SizedBox(height: 12),
              const Text('Scan this one-time code with Peo Yame on the other phone.'),
              const SizedBox(height: 8),
              Text('Expires ${TimeOfDay.fromDateTime(expiresAt).format(dialogContext)}', style: const TextStyle(color: Color(0xFF65776F), fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create a sign-in QR code: ${error.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      api.dispose();
    }
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
                    'Enter the room-monitoring target band. Confirm guidance for the crop and its condition.',
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
        await _controller.setHarvest(fields[0].text.trim());
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
    _controller.removeListener(_handleDashboardUpdate);
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
                icon: Icon(Icons.eco_outlined),
                selectedIcon: Icon(Icons.eco_rounded),
                label: 'My Crops',
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
      2 => _myCropsContent(status),
      3 => _alertsContent(status),
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
      userName: _accountName,
      isDemo: widget.token == null,
      onSettingsTap: _openSettings,
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

  List<Widget> _myCropsContent(StatusResponse? status) => [
    const _SectionTitle(title: 'My Crops'),
    const SizedBox(height: 4),
    Text(
      widget.token == null
          ? 'Shared demo crop catalog · locations and sensor links are not saved to an account.'
          : 'Crop monitoring guides and your saved storage locations.',
      style: const TextStyle(color: Color(0xFF65776F), fontSize: 13),
    ),
    const SizedBox(height: 12),
    if (widget.token != null) ...[
      FarmerLocationsPanel(
        baseUrl: _controller.baseUrl,
        token: widget.token!,
        crops: _controller.crops,
        accountRevision: _controller.farmerAccountRevision,
      ),
      const SizedBox(height: 18),
    ],
    if (widget.token == null)
      const _SimulationBanner(),
    if (widget.token == null) ...[
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Expanded(
                child: Text('Crop monitoring limits are shared with the dashboard. Add a crop to the catalog or choose one to monitor.'),
              ),
              IconButton(onPressed: _addCrop, tooltip: 'Add crop', icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
        ),
      ),
    ],
    const SizedBox(height: 8),
    TextField(
      onChanged: (value) => setState(() => _cropGuideSearch = value),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        labelText: 'Search crop guides',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 8),
    if (_visibleCropGuides.isEmpty)
      _EmptyCard(
        icon: Icons.eco_outlined,
        text: _controller.crops.isEmpty
            ? 'Crop guides are unavailable while the backend is offline.'
            : 'No crop guides match this search.',
      )
    else
      ..._visibleCropGuides.map((crop) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.eco_outlined, color: _forest),
          title: Text(crop.commodity, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${crop.minTemp}–${crop.maxTemp} °C · ${crop.minHumidity}–${crop.maxHumidity}% RH'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${crop.cropGroup}\nRoom target band: ${crop.minTemp}–${crop.maxTemp} °C and ${crop.minHumidity}–${crop.maxHumidity}% RH.${crop.safeMoisturePct == null ? '' : '\nGrain moisture guide: at or below ${crop.safeMoisturePct}%; measure separately with a moisture meter.'}\n${crop.storageNote}',
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
            if (status != null && status.threshold.commodity != crop.commodity)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _controller.setHarvest(crop.commodity),
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: const Text('Monitor this crop'),
                ),
              )
            else if (status?.threshold.commodity == crop.commodity)
              const Align(alignment: Alignment.centerRight, child: Chip(label: Text('Currently monitored'))),
          ],
        ),
      )),
    if (widget.token == null) ...[
      const SizedBox(height: 10),
      const _EmptyCard(icon: Icons.warehouse_outlined, text: 'No crop locations or linked physical sensors are saved in shared Demo mode.'),
    ],
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
            child: _AlertTile(
              alert: alert,
              onAcknowledge: alert.acknowledged
                  ? null
                  : () => _controller.acknowledgeAlert(alert.id),
            ),
          ),
        ),
      const SizedBox(height: 16),
      const _SectionTitle(title: 'SMS dispatch log · simulation only'),
      const SizedBox(height: 8),
      const Text(
        'These entries are recorded locally by the demo backend. No text message is sent.',
        style: TextStyle(color: Color(0xFF65776F), fontSize: 12),
      ),
      const SizedBox(height: 8),
      if (_controller.smsLog.isEmpty)
        const _EmptyCard(
          icon: Icons.sms_outlined,
          text: 'No simulated dispatch entries yet.',
        )
      else
        ..._controller.smsLog.take(10).map((entry) => Card(
          child: ListTile(
            leading: const Icon(Icons.sms_outlined, color: _forest),
            title: Text('${entry['body'] ?? 'Alert dispatch'}', maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${entry['status'] ?? 'logged'} · ${_formatDate('${entry['createdAt'] ?? ''}')}'),
          ),
        )),
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
              'Preview different readings outside the configured range',
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
    const _SectionTitle(title: 'Profile'),
    const SizedBox(height: 8),
    Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _AccountDetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Name',
              value: _accountName,
            ),
            const Divider(height: 1),
            _AccountDetailRow(
              icon: Icons.mail_outline_rounded,
              label: _accountEmail == 'Demo profile'
                  ? 'Profile'
                  : 'Email',
              value: _accountEmail,
            ),
            if (widget.token != null) ...[
              const Divider(height: 1),
              _AccountDetailRow(
                icon: Icons.phone_outlined,
                label: 'Number',
                value: _accountPhone,
              ),
            ],
          ],
        ),
      ),
    ),
    if (widget.token != null) ...[
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _editProfile,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit full profile'),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _loadingAuthenticator ? null : _setupAuthenticator,
        icon: const Icon(Icons.security_rounded),
        label: Text(_loadingAuthenticator
            ? 'Checking authenticator…'
            : _authenticatorEnabled
                ? 'Turn off authenticator sign-in'
                : 'Set up authenticator sign-in'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
      ),
      const SizedBox(height: 16),
    ],
    const _SectionTitle(title: 'Accounts'),
    const SizedBox(height: 8),
    Card(
      child: ListTile(
        leading: const Icon(Icons.eco_outlined, color: _forest),
        title: const Text('My Crops'),
        subtitle: Text(widget.token == null
            ? 'Browse the shared crop catalog.'
            : 'Manage crop locations and linked sensors.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _selectedTab = 2),
      ),
    ),
    if (widget.token != null) ...[
      Card(
        child: ListTile(
          leading: const Icon(Icons.qr_code_2_rounded, color: _forest),
          title: const Text('Link another phone'),
          subtitle: const Text('Show a one-time QR code to connect this backend and sign in on another Peo Yame phone.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showSignInQr,
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.qr_code_scanner_rounded, color: _forest),
          title: const Text('Approve browser sign-in'),
          subtitle: const Text('Scan a one-time code from the Peo Yame web sign-in page.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _scanBrowserLoginQr,
        ),
      ),
    ],
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
    final crop = status?.threshold;
    final moisture = crop?.safeMoisturePct;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Crop storage guide', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (crop == null)
              const Text('Connect to a monitor to view the selected crop guide.')
            else ...[
              Text('${crop.cropGroup} · ${crop.commodity}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text('Room target: ${crop.minTemp}–${crop.maxTemp} °C and ${crop.minHumidity}–${crop.maxHumidity}% RH.'),
              if (moisture != null) ...[
                const SizedBox(height: 5),
                Text('Grain moisture guide: at or below $moisture%. Measure with a grain moisture meter; room humidity does not measure grain moisture.'),
              ],
              if (crop.storageNote.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(crop.storageNote, style: const TextStyle(color: Color(0xFF65776F), fontSize: 11)),
              ],
            ],
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
                color: const Color(0xFFFFF7E5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'This alert shows a reading outside the configured room target band. It does not predict crop quality or storage life.',
                style: TextStyle(color: Color(0xFF624D1C), fontSize: 11, height: 1.35),
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
        'Target: $safeRange',
        style: const TextStyle(color: Color(0xFF65776F), fontSize: 10),
      ),
    ],
  );
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .22),
    child: Image.asset(
      'assets/branding/peo-yame-128.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: 'Peo Yame logo',
    ),
  );
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
    required this.isDemo,
    required this.onSettingsTap,
    required this.onLogout,
  });

  final String userName;
  final bool isDemo;
  final VoidCallback onSettingsTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PopupMenuButton<String>(
          tooltip: 'User menu',
          onSelected: (value) {
            if (value == 'settings') onSettingsTap();
            if (value == 'logout') onLogout();
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text('$userName${isDemo ? ' · Shared demo profile' : ''}', style: const TextStyle(color: _forest)),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 18),
                  const SizedBox(width: 10),
                  const Text('Settings'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(isDemo ? 'Exit Demo mode' : 'Log out'),
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
                isDemo ? 'Shared Demo profile · simulated readings' : 'Your harvest at a glance',
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
                      : 'Readings are within the target band',
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
              'Target ${_fmt(min)}–${_fmt(max)}',
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
    final cropOptions = <String>{
      status.threshold.commodity,
      ...crops.map((crop) => crop.commodity),
    };
    final moisture = status.threshold.safeMoisturePct;
    final guidance = [
      if (moisture != null)
        'Grain moisture guide: ≤$moisture% (measure separately with a grain moisture meter).',
      status.threshold.storageNote,
    ].where((text) => text.isNotEmpty).join(' ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      const Text('Crop in storage', style: TextStyle(fontSize: 11, color: Color(0xFF65776F))),
                      DropdownButton<String>(
                        value: status.threshold.commodity,
                        isDense: true,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        onChanged: isChanging
                            ? null
                            : (crop) { if (crop != null) onChanged(crop); },
                        items: cropOptions.map((crop) => DropdownMenuItem(value: crop, child: Text(crop))).toList(),
                      ),
                    ],
                  ),
                ),
                if (isChanging) ...[
                  const SizedBox(width: 8),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
            if (guidance.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(guidance, style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF65776F))),
            ],
          ],
        ),
      ),
    );
  }
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
  const _AlertTile({required this.alert, required this.onAcknowledge});

  final Alert alert;
  final VoidCallback? onAcknowledge;

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
          '${_formatDate(alert.sentAt)} · ${alert.acknowledged ? 'Reviewed' : 'Needs attention'}',
          style: const TextStyle(fontSize: 10),
        ),
        trailing: onAcknowledge == null
            ? null
            : IconButton(
                tooltip: 'Mark reviewed',
                onPressed: onAcknowledge,
                icon: const Icon(Icons.check_circle_outline),
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
          breached ? 'Alert' : 'In range',
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
