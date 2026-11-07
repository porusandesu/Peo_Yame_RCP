import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:storage_monitor_flutter/main.dart';

void main() {
  testWidgets('StorageMonitorApp offers a direct demo mode without login', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const StorageMonitorApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Peo Yame'), findsOneWidget);
    expect(find.text('Mr Lesego Lefoko'), findsOneWidget);
    expect(find.text('LLefoko@email.co.bw'), findsOneWidget);
    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.text('Sign in securely'), findsNothing);
    expect(find.text('Scan sign-in QR'), findsNothing);
    expect(find.text('Continue with OTP'), findsNothing);
  });
}
