import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:storage_monitor_flutter/main.dart';

void main() {
  testWidgets('StorageMonitorApp opens the demo home without sign-in', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const StorageMonitorApp());
    await tester.pumpAndSettle();

    expect(find.text('Demo Farmer'), findsWidgets);
    expect(find.text('Sign in securely'), findsNothing);
    expect(find.text('Scan sign-in QR'), findsNothing);
    expect(find.text('Continue with OTP'), findsNothing);
  });
}
