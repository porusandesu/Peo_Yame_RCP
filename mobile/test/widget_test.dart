import 'package:flutter_test/flutter_test.dart';
import 'package:peo_yame/main.dart';
void main(){testWidgets('five destinations and estimate disclaimer', (tester) async {
  await tester.pumpWidget(const PeoYameApp());
  for(final label in ['Overview','Trends','My Crops','Alerts','Settings']) { expect(find.text(label),findsWidgets); }
  expect(find.textContaining('Check your crops by hand'),findsOneWidget);
});}
