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
    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.text('Continue with OTP'), findsNothing);
    expect(find.text('Verify your code'), findsNothing);

    await tester.tap(find.text('Demo mode'));
    await tester.pump();

    expect(find.text('Mr Lesego Lefoko'), findsOneWidget);
    expect(find.text('Readings will appear here when the monitor connects.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
