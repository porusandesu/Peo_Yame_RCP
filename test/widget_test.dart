import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_monitor_flutter/account_screens.dart';
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

  testWidgets('signed-in account exposes both one-time QR sign-in actions', (
    WidgetTester tester,
  ) async {
    var showQrRequested = false;
    var scanRequested = false;
    var locationsRequested = false;
    var profileEditRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => AccountsScreen(
                    name: 'Lesego Farmer',
                    email: 'lesego@example.test',
                    phone: '+26771234567',
                    isDemo: false,
                    onLogout: () {},
                    onDestinationSelected: (_) {},
                    onShowSignInQr: () => showQrRequested = true,
                    onScanSignInQr: () => scanRequested = true,
                    onManageLocations: () => locationsRequested = true,
                    onEditProfile: () => profileEditRequested = true,
                  ),
                ),
              ),
              child: const Text('Open account'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Manage linked sensors'));
    await tester.tap(find.text('Manage linked sensors'));
    await tester.pumpAndSettle();
    expect(locationsRequested, isTrue);
    await tester.tap(find.text('Open account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(profileEditRequested, isTrue);
    await tester.tap(find.text('Open account'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Show sign-in QR code'));
    await tester.tap(find.text('Show sign-in QR code'));
    await tester.pump();
    expect(showQrRequested, isTrue);
    await tester.ensureVisible(find.text('Approve browser sign-in'));
    await tester.tap(find.text('Approve browser sign-in'));
    await tester.pump();
    expect(scanRequested, isTrue);
  });
}
