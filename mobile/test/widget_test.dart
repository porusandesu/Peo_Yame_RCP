import 'package:flutter_test/flutter_test.dart';
import 'package:peo_yame/main.dart';

void main() {
  testWidgets('Welcome screen exposes demo and account entry', (tester) async {
    await tester.pumpWidget(const PeoYameApp());
    expect(find.text('Explore Demo mode'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Backend address'), findsNothing);
  });

  testWidgets('Backend configuration opens on its own screen', (tester) async {
    await tester.pumpWidget(const PeoYameApp());
    await tester.tap(find.text('Connect to backend'));
    await tester.pump();
    expect(find.text('Backend address'), findsOneWidget);
    expect(find.text('Sign in with QR code'), findsNothing);
  });
}
