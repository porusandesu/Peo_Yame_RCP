import 'package:flutter_test/flutter_test.dart';
import 'package:peo_yame/main.dart';

void main() {
  test('gauge position handles target, out-of-range, missing and edge values', () {
    final inBand = gaugePosition(15, 12, 16);
    expect(inBand.state, 'In range');
    expect(inBand.fraction, closeTo(.625, .001));
    expect(inBand.bandStart, closeTo(.25, .001));
    expect(inBand.bandEnd, closeTo(.75, .001));
    expect(gaugePosition(30, 12, 16).state, 'Above target');
    expect(gaugePosition(-20, 12, 16).state, 'Below target');
    expect(gaugePosition(null, 12, 16).state, 'No reading');
    final edge = gaugePosition(0, 0, 20, percent: true);
    expect(edge.bandStart, 0);
    expect(edge.state, 'In range');
  });

  test('trend ticks use readable intervals and cover the range', () {
    for (final range in [[11.3, 18.7], [45.0, 93.0], [0.2, 0.9]]) {
      final ticks = niceTicks(range[0], range[1]);
      expect(ticks.length, inInclusiveRange(4, 6));
      expect(ticks.first, lessThanOrEqualTo(range[0]));
      expect(ticks.last, greaterThanOrEqualTo(range[1]));
    }
  });

  test('backend address masking preserves the port without exposing the full IP', () {
    expect(
      maskedBackendAddress('http://192.168.1.42:3000'),
      'http://192.168.1.•••:3000',
    );
  });

  test('reading age caption switches to a paused state after one minute', () {
    expect(readingAgeCaption(8), 'Simulated · updated 8 s ago');
    expect(readingAgeCaption(61), 'Simulated readings are paused');
  });

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

  test('failed backend validation preserves the current session', () async {
    var sessionEnded = false;
    var destinationSaved = false;

    await expectLater(
      runValidatedBackendSwitch<String>(
        validateDestination: () async => throw StateError('unreachable'),
        endCurrentSession: () async {
          sessionEnded = true;
        },
        saveDestination: (_) async {
          destinationSaved = true;
        },
      ),
      throwsA(isA<StateError>()),
    );

    expect(sessionEnded, isFalse);
    expect(destinationSaved, isFalse);
  });

  test('successful backend switching validates before saving the destination', () async {
    final steps = <String>[];

    await runValidatedBackendSwitch<String>(
      validateDestination: () async {
        steps.add('validated');
        return 'http://192.168.1.20:3000';
      },
      endCurrentSession: () async {
        steps.add('signed out');
      },
      saveDestination: (destination) async {
        steps.add('saved $destination');
      },
    );

    expect(steps, [
      'validated',
      'signed out',
      'saved http://192.168.1.20:3000',
    ]);
  });

  testWidgets('Welcome screen exposes demo and account entry', (tester) async {
    await tester.pumpWidget(const PeoYameApp());
    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Scan sign-in or backend QR'), findsOneWidget);
    expect(find.textContaining('open the Peo Yame web dashboard'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Backend address'), findsNothing);
    expect(find.text('Connect to backend'), findsNothing);
  });

}
