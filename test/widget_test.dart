import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_monitor_flutter/main.dart';

void main() {
  testWidgets('demo opens the home page without a phone verification step', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StorageMonitorApp());

    expect(find.text('Mr Lesego Lefoko'), findsOneWidget);
    expect(find.text('LLefoko@email.co.bw'), findsOneWidget);
    expect(find.text('Shared demo profile'), findsOneWidget);
    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.text('Continue with OTP'), findsNothing);
    expect(find.text('Verify your code'), findsNothing);

    await tester.tap(find.text('Demo mode'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Mr Lesego Lefoko'), findsOneWidget);
    expect(find.textContaining('Shared Demo profile'), findsOneWidget);
    expect(
      find.text('Readings will appear here when the monitor connects.'),
      findsOneWidget,
    );
    expect(find.text('My Crops'), findsOneWidget);

    await tester.tap(find.text('My Crops'));
    await tester.pump();
    expect(find.textContaining('Shared demo crop catalog'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pump();
    expect(
      find.textContaining('No crop locations or linked physical sensors'),
      findsOneWidget,
    );

    await tester.tap(find.text('Alerts').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Trigger demo breach'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mobile settings orders Profile before Accounts and keeps phone QR there', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          account: const AccountInfo(
            name: 'Lesego Farmer',
            email: 'lesego@example.test',
            phone: '+26771234567',
          ),
          token: 'test-session-token',
          baseUrl: 'http://127.0.0.1:3000',
          onLogout: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Link another phone'), findsOneWidget);
    expect(find.text('Approve browser sign-in'), findsOneWidget);
    expect(find.text('Demo mode'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Profile')).dy,
      lessThan(tester.getTopLeft(find.text('Accounts')).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
