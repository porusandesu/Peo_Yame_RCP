import 'package:flutter_test/flutter_test.dart';
import 'package:peo_yame/main.dart';
void main(){testWidgets('Welcome screen exposes the one-tap demo and account entry', (tester) async {await tester.pumpWidget(const PeoYameApp());expect(find.text('Explore Demo mode'),findsOneWidget);expect(find.text('Sign in'),findsOneWidget);expect(find.text('Create account'),findsOneWidget);});}
