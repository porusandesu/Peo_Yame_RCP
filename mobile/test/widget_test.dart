import 'package:flutter_test/flutter_test.dart';
import 'package:peo_yame/main.dart';

void main() {
  test('HTTP backend must use a private IP literal', () {
    expect(isPrivateBackendUrl(Uri.parse('http://10.2.3.4:3000')), isTrue);
    expect(isPrivateBackendUrl(Uri.parse('http://172.20.1.4:3000')), isTrue);
    expect(isPrivateBackendUrl(Uri.parse('http://192.168.1.4:3000')), isTrue);
    expect(isPrivateBackendUrl(Uri.parse('http://10.attacker.example')), isFalse);
    expect(isPrivateBackendUrl(Uri.parse('http://192.168.attacker.example')), isFalse);
    expect(isPrivateBackendUrl(Uri.parse('http://172.16.attacker.example')), isFalse);
    expect(isPrivateBackendUrl(Uri.parse('http://8.8.8.8')), isFalse);
    expect(isPrivateBackendUrl(Uri.parse('https://example.com')), isTrue);
    expect(isPrivateBackendUrl(Uri.parse('https:///missing-host')), isFalse);
    expect(isPrivateBackendUrl(Uri.parse('https://user:pass@example.com')), isFalse);
  });

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
