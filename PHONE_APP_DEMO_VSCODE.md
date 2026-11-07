# Build the Phone App in VS Code and Connect It to the PC (Demo Guide)

> **Historical build tutorial.** This file contains an older hand-built Flutter
> example and setup steps. The current app in this repository is already in
> `lib/`; use the root [README](README.md) to run it. The current demo opens
> directly with **Demo mode** and has no phone/PIN verification step.

Goal: a Flutter app on an Android phone that shows live (simulated) storage
readings and alerts from the backend running on a PC, over the same Wi-Fi.
Everything is done in VS Code. No Android Studio window is needed, only its SDK.

```text
 Phone (Flutter app)  --HTTP, same Wi-Fi-->  PC: backend on port 3000
   gear icon sets                              (API + dashboard + simulator)
   the PC address                              http://<PC-IP>:3000
```

Honesty note for reports and the presentation: the data is **simulated**
(no physical sensors) and SMS alerts are **logged, not sent**.

If the patched project (`storage_monitor_flutter_patched.zip`) is available,
skip Part 3 and use it: unzip it, open the folder in VS Code, go to Part 4.

---

## Part 1: Install once

| Tool | Notes |
|---|---|
| VS Code | with extensions **Flutter** and **Dart** (Flutter pulls in Dart) |
| Flutter SDK | download stable, unzip, add `flutter/bin` to PATH |
| JDK **17** | not 25. Set `JAVA_HOME` to it |
| Android SDK | easiest via Android Studio install (SDK Manager: Platform-Tools, a recent Platform, Build-Tools, Command-line Tools) |
| Node.js 20+ | for the backend |

Then in a terminal:
```bash
flutter config --jdk-dir "<path to JDK 17>"
flutter doctor --android-licenses     # press y to accept all
flutter doctor                        # fix anything marked with a cross for Android
```
Android Studio is not required afterwards. Close it to save memory.

---

## Part 2: Start the backend on the PC

Use the existing backend (`storage-demo/backend`) or the one built from
`BUILD_GUIDE_CURSOR.md`.

```bash
cd backend
npm install
npm run demo        # serves http://localhost:3000
```
Open `http://localhost:3000` in the PC browser: you should see the dashboard
with changing readings.

**Find the PC's Wi-Fi address** (the phone will use it):
- Windows: `ipconfig` -> "IPv4 Address" of the Wi-Fi adapter
- macOS: `ipconfig getifaddr en0`
- Linux: `hostname -I`

It looks like `192.168.x.x`. It changes on each network, so re-check it before
every demo.

**Allow the port through the firewall** (otherwise the phone cannot connect):
- Windows (Admin PowerShell):
  `netsh advfirewall firewall add rule name="Node3000" dir=in action=allow protocol=TCP localport=3000`
- Linux: `sudo ufw allow 3000`
- macOS: click Allow if asked about Node incoming connections

The server must listen on `0.0.0.0` (not only `127.0.0.1`).

**Test from the phone before touching the app:** connect the phone to the same
Wi-Fi, open `http://<PC-IP>:3000` in the phone browser. If the dashboard loads,
the network is fine. If not, fix this first (firewall, same network, or use the
PC's mobile hotspot, because some campus/venue Wi-Fi blocks device-to-device
traffic).

---

## Part 3: Create the app

In VS Code open a terminal in the project root:
```bash
flutter create --org com.group3 --project-name storage_monitor mobile
cd mobile
flutter pub add http shared_preferences
```
Open the `mobile` folder in VS Code (File > Open Folder).

### 3.1 Android permissions (required, or the phone cannot connect)
Edit `android/app/src/main/AndroidManifest.xml`:

1. Directly inside `<manifest ...>`, before `<application`, add:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
2. On the `<application` tag, add the attribute:
```xml
android:usesCleartextTraffic="true"
```
(The backend uses plain `http://`, which Android blocks by default in release
builds.)

### 3.2 Replace `lib/main.dart` with this complete app
```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Emulator default. A real phone must use the PC's LAN IP (gear icon).
const String defaultBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');
const String prefKey = 'api_base_url';

void main() => runApp(const StorageMonitorApp());

class StorageMonitorApp extends StatelessWidget {
  const StorageMonitorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Storage Monitor',
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        home: const DashboardPage(),
      );
}

// ---------- models (match the frozen API shapes) ----------
class Reading {
  final double temperature, humidity;
  final String recordedAt;
  Reading(this.temperature, this.humidity, this.recordedAt);
  factory Reading.fromJson(Map<String, dynamic> j) => Reading(
      (j['temperature'] as num).toDouble(),
      (j['humidity'] as num).toDouble(),
      j['recordedAt'] as String);
}

class Threshold {
  final String commodity;
  final double minTemp, maxTemp, minHumidity, maxHumidity;
  Threshold(this.commodity, this.minTemp, this.maxTemp, this.minHumidity,
      this.maxHumidity);
  factory Threshold.fromJson(Map<String, dynamic> j) => Threshold(
      j['commodity'] as String,
      (j['minTemp'] as num).toDouble(),
      (j['maxTemp'] as num).toDouble(),
      (j['minHumidity'] as num).toDouble(),
      (j['maxHumidity'] as num).toDouble());
}

class StatusResponse {
  final Reading? latest;
  final Threshold threshold;
  final bool breached;
  StatusResponse(this.latest, this.threshold, this.breached);
  factory StatusResponse.fromJson(Map<String, dynamic> j) => StatusResponse(
      j['latest'] == null
          ? null
          : Reading.fromJson(j['latest'] as Map<String, dynamic>),
      Threshold.fromJson(j['threshold'] as Map<String, dynamic>),
      j['breached'] as bool);
}

class AlertItem {
  final String message, sentAt;
  final String? severity;
  AlertItem(this.message, this.sentAt, this.severity);
  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
      j['message'] as String, j['sentAt'] as String, j['severity'] as String?);
}

String fmtTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

String normaliseUrl(String input) {
  var u = input.trim();
  if (u.isEmpty) return defaultBaseUrl;
  if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

// ---------- screen ----------
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _baseUrl = defaultBaseUrl;
  StatusResponse? _status;
  List<AlertItem> _alerts = [];
  String? _error;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _baseUrl = prefs.getString(prefKey) ?? defaultBaseUrl;
    } catch (_) {}
    await _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await http
          .get(Uri.parse('$_baseUrl/api/status'))
          .timeout(const Duration(seconds: 4));
      final a = await http
          .get(Uri.parse('$_baseUrl/api/alerts'))
          .timeout(const Duration(seconds: 4));
      if (s.statusCode != 200 || a.statusCode != 200) {
        throw Exception('HTTP ${s.statusCode} / ${a.statusCode}');
      }
      final status =
          StatusResponse.fromJson(jsonDecode(s.body) as Map<String, dynamic>);
      final alerts = (jsonDecode(a.body) as List<dynamic>)
          .map((e) => AlertItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _status = status;
        _alerts = alerts;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            "Can't reach $_baseUrl. Is the backend running, and is this phone on the same Wi-Fi? Tap the gear to change the address. ($e)";
        _loading = false;
      });
    }
  }

  Future<void> _editServer() async {
    final controller = TextEditingController(text: _baseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server address'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: '192.168.1.42:3000',
            helperText: 'PC Wi-Fi IP + port 3000',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    final url = normaliseUrl(result);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, url);
    } catch (_) {}
    setState(() {
      _baseUrl = url;
      _loading = true;
      _error = null;
    });
    await _refresh();
  }

  Widget _statusCard(StatusResponse s) {
    final breached = s.breached;
    final r = s.latest;
    final t = s.threshold;
    return Card(
      color: breached ? Colors.red.shade100 : Colors.green.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(breached ? 'Threshold breached' : 'Conditions normal',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (r != null) ...[
            Text('Temperature: ${r.temperature.toStringAsFixed(1)} °C'),
            Text('Humidity: ${r.humidity.toStringAsFixed(1)} %'),
            Text('Updated ${fmtTime(r.recordedAt)}',
                style: const TextStyle(color: Colors.black54)),
          ] else
            const Text('No readings yet'),
          const SizedBox(height: 8),
          Text(
              'Safe range for ${t.commodity}: ${t.minTemp}-${t.maxTemp} °C, ${t.minHumidity}-${t.maxHumidity} % RH',
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Monitor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Server address',
              onPressed: _editServer),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            color: Colors.amber.shade100,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Text('Simulated data. No physical sensors.',
                  textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                  padding: const EdgeInsets.all(12), child: Text(_error!)),
            ),
          if (_loading && _status == null)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator())),
          if (_status != null) _statusCard(_status!),
          const SizedBox(height: 24),
          Text('Recent alerts',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_alerts.isEmpty) const Text('No alerts yet.'),
          for (final a in _alerts.take(20))
            Card(
              child: ListTile(
                leading: Icon(Icons.warning_amber,
                    color: a.severity == 'critical'
                        ? Colors.red
                        : Colors.orange),
                title: Text(a.message),
                subtitle: Text(fmtTime(a.sentAt)),
              ),
            ),
        ]),
      ),
    );
  }
}
```

Check it compiles cleanly:
```bash
flutter analyze
```

---

## Part 4: Run it on the phone from VS Code

**Prepare the phone (Android, e.g. Samsung A07):**
1. Settings > About phone > Software information > tap **Build number** 7 times.
2. Settings > Developer options > turn on **USB debugging**.
3. Connect by USB and accept the "Allow USB debugging" prompt.
4. On newer Samsung phones, if installs are blocked, turn off
   Settings > Security and privacy > **Auto Blocker** for the demo.

**Run from VS Code:**
1. Press `Ctrl+Shift+P` > "Flutter: Select Device" and pick the phone (it also
   shows in the bottom-right status bar). Check with `flutter devices`.
2. Press `F5` (Run > Start Debugging). The first build takes several minutes
   and uses a lot of CPU; later runs are fast with hot reload.
3. On the phone, tap the **gear icon**, type `<PC-IP>:3000`, tap Save.
4. The status card should turn green and readings should update every 5 s.

**Install a standalone APK for the demo (no cable needed afterwards):**
```bash
flutter build apk --release
flutter install            # or copy build/app/outputs/flutter-apk/app-release.apk to the phone
```
Use the debug build (`flutter build apk --debug`) if the release build fails.

**Wireless option** (Android 11+): Developer options > Wireless debugging >
pair with `adb pair <ip:port>` then `adb connect <ip:port>`.

### Optional VS Code helpers
`.vscode/tasks.json` in the project root (starts the backend with one command):
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start backend",
      "type": "shell",
      "command": "npm run demo",
      "options": { "cwd": "${workspaceFolder}/backend" },
      "isBackground": true,
      "problemMatcher": []
    }
  ]
}
```
Run it with `Ctrl+Shift+P` > "Tasks: Run Task" > "Start backend".

`mobile/.vscode/launch.json` (bake in an address so you can skip the gear):
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Phone (PC at 192.168.1.42)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=API_BASE_URL=http://192.168.1.42:3000"]
    }
  ]
}
```
Change the IP to your PC's. The gear icon setting overrides it once saved.

---

## Part 5: Demo script (5 minutes)

Before presenting (10 minutes early):
- [ ] PC and phone on the same Wi-Fi (or the PC's hotspot)
- [ ] Backend running, PC IP re-checked, firewall rule in place
- [ ] Phone browser loads `http://<PC-IP>:3000`
- [ ] App installed, address saved, status card updating
- [ ] Laptop plugged in and cool; close other apps
- [ ] Backup: a short screen recording and screenshots of the working demo

During the demo:
1. Show the PC dashboard (banner says data is simulated) and the phone app side by side.
2. Say what is real and what is simulated: the architecture and alert logic are
   real; the sensor values come from a modelled simulator; SMS is logged.
3. On the PC control panel, switch to **busy-day** mode (door events cause
   spikes) or press **Inject breach**.
4. Show the phone turning red within about 5 seconds, with the new alert in
   the list. Show the alert and SMS log entry with timestamps on the PC.
5. Optionally restart the backend and show that earlier readings persist.
6. State the limitations: no physical sensors yet, no real GSM transmission,
   single site; these are future work.

If the app cannot connect during the demo: check the address (gear icon),
switch to the PC's hotspot, or fall back to the recording.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Can't reach http://10.0.2.2:3000" on a phone | That address is for the emulator only. Tap the gear and enter `<PC-IP>:3000` |
| Phone browser can't open `http://<PC-IP>:3000` | Different networks, firewall, or Wi-Fi client isolation. Allow port 3000, or use a hotspot |
| Works in the browser but not in the app | Missing INTERNET permission or `usesCleartextTraffic` in the manifest (Part 3.1) |
| Gradle error about Java 25 | Use JDK 17: `flutter config --jdk-dir <jdk17>`, then `cd android && ./gradlew --stop` and rebuild |
| `flutter doctor` complains about licenses | `flutter doctor --android-licenses` |
| Phone not listed in `flutter devices` | Re-plug the cable, accept the USB prompt, try another cable, check USB debugging |
| Install blocked on Samsung | Turn off Auto Blocker; allow install from the source if prompted |
| App shows data but never changes | Backend simulator stopped; start it from the dashboard control panel |
| Laptop overheating | Build the APK once, then run the installed APK instead of debug sessions; close Chrome and other IDEs |

---

## Optional: have an AI assistant do Part 3 for you
Paste into Cursor or Copilot Chat, then run the checks above yourself:
```text
Following @PHONE_APP_DEMO_VSCODE.md Part 3, create the Flutter app in mobile/.
Add the Android manifest changes, replace lib/main.dart with the code in the
guide, and run flutter analyze. Do not change the API shapes. Do not build the APK.
```
