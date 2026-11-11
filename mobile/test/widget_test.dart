import 'package:flutter_test/flutter_test.dart';
import 'package:peo_yame/main.dart';
void main(){testWidgets('welcome exposes one-tap demo and five main sections', (tester) async {
  await tester.pumpWidget(const PeoYameApp());
  expect(find.text('Explore Demo mode'),findsOneWidget);
  await tester.tap(find.text('Explore Demo mode'));
  await tester.pumpAndSettle();
  for(final label in ['Overview','Trends','My Crops','Alerts','Settings']){expect(find.text(label),findsWidgets);}
  expect(find.textContaining('Check your crops by hand'),findsOneWidget);
});}
