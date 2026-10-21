import 'package:flutter_test/flutter_test.dart';

import 'package:storage_monitor_flutter/main.dart';

void main() {
  testWidgets('StorageMonitorApp builds the Peo Yame mobile dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const StorageMonitorApp());
    await tester.pump();

    expect(find.text('Peo Yame'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Trends'), findsWidgets);
    expect(find.text('Alerts'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
