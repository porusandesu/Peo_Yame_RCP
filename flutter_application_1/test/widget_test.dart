import 'package:flutter_test/flutter_test.dart';

import 'package:storage_monitor_flutter/main.dart';

void main() {
  testWidgets('StorageMonitorApp builds dashboard scaffold', (tester) async {
    await tester.pumpWidget(const StorageMonitorApp());
    await tester.pump();

    expect(find.text('Peo Yame'), findsAtLeastNWidgets(1));
  });
}
