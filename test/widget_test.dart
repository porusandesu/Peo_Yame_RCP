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

    expect(find.text('Mr Lesego Lefoko'), findsOneWidget);
    expect(find.textContaining('Shared Demo profile'), findsOneWidget);
    expect(find.text('Readings will appear here when the monitor connects.'), findsOneWidget);
    expect(find.text('My Crops'), findsOneWidget);

    await tester.tap(find.text('My Crops'));
    await tester.pump();
    expect(find.textContaining('Shared demo crop catalog'), findsOneWidget);
    expect(find.textContaining('No crop locations or linked physical sensors'), findsOneWidget);

    await tester.tap(find.text('Alerts'));
    await tester.pump();
    expect(find.text('Trigger demo breach'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
