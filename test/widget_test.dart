import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:storage_monitor_flutter/main.dart';

void main() {
  testWidgets('StorageMonitorApp shows sign-in for a fresh install', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const StorageMonitorApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Connect to web backend'), findsOneWidget);
  });
}
